require "logger"
require "active_record"

module Outboxer
  module Event
    module_function

    class Error < StandardError; end;
    class NotFound < Error; end
    class InvalidTransition < Error; end

    # publish an unpublished outboxer eventable
    #
    # This method retrieves an unpublished event, set it to publishing and then yields it to
    # the provided block. The event is marked as readonly to prevent modifications
    # during processing. If an error occurs during the yield, the method rescues
    # the exception, sets the event status to failed, and re-raises the exception.
    # Upon successful processing, the event status is set to published.
    #
    # @yield [outboxer_eventable] Yields the polymorphically associated model.
    # @yieldparam outboxer_eventable The readonly event from outboxer.
    #
    # @raise [Outboxer::Event::NotFound] If no unpublished event is found in the queue.
    # @raise [StandardError] Reraises any exception that occurs during the yield.
    #
    # @example Publish event
    #   Outboxer::Event.publish! do |outboxer_eventable|
    #     EventHandlerWorker.perform_async({ 'event' => {'id' => outboxer_eventable.id } })
    #   end

    def self.publish!
      outboxer_event = unpublished!

      begin
        yield outboxer_event.outboxer_eventable
      rescue => exception
        failed!(id: outboxer_event.id, exception: exception)

        raise
      end

      published!(id: outboxer_event.id)
    end

    def self.unpublished!
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          outboxer_event = Models::Event
            .includes(:outboxer_eventable)
            .where(status: Models::Event::STATUS[:unpublished])
            .order(created_at: :asc)
            .limit(1)
            .lock("FOR UPDATE SKIP LOCKED")
            .first

          outboxer_event.update!(status: Models::Event::STATUS[:publishing])

          outboxer_event.outboxer_eventable.readonly!

          outboxer_event
        end
      end
    rescue ActiveRecord::RecordNotFound => exception
      raise NotFound.new(exception)
    end

    def self.published!(id:)
      ActiveRecord::Base.connection_pool.with_connection do
        outboxer_event = Models::Event
          .order(created_at: :asc)
          .lock
          .find_by!(id: id)

        if outboxer_event.status != Models::Event::STATUS[:publishing]
          raise InvalidTransition,
            "cannot transition outboxer event #{outboxer_event.id} " \
            "from #{outboxer_event.status} to (deleted)"
        end

        outboxer_event.destroy!
      end
    end

    def self.failed!(id:, exception:)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          outboxer_event = Models::Event
            .order(created_at: :asc)
            .lock
            .find_by!(id: id)

          if outboxer_event.status != Models::Event::STATUS[:publishing]
            raise InvalidTransition,
              "cannot transition outboxer event #{id} " \
              "from #{outboxer_event.status} to #{Models::Event::STATUS[:failed]}"
          end

          outboxer_event.update!(status: Models::Event::STATUS[:failed])

          outboxer_event.outboxer_exceptions.create!(
            class_name: exception.class.name,
            message_text: exception.message,
            backtrace: exception.backtrace)
        end
      end
    end

    def self.republish!(id:)
      ActiveRecord::Base.connection_pool.with_connection do
        outboxer_event = Models::Event
          .order(created_at: :asc)
          .lock
          .find_by!(id: id)

        if outboxer_event.status != Models::Event::STATUS[:failed]
          raise InvalidTransition,
            "cannot transition outboxer event #{id} " \
            "from #{outboxer_event.status} to #{Models::Event::STATUS[:failed]}"
        end

        outboxer_event.update!(status: Models::Event::STATUS[:unpublished])
      end
    end

    private_class_method :unpublished!
  end
end
