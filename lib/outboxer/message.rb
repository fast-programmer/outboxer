require "logger"
require "active_record"

module Outboxer
  module Message
    module_function

    class Error < StandardError; end;
    class NotFound < Error; end
    class InvalidTransition < Error; end

    # publish an unpublished outboxer messageable
    #
    # This method retrieves an unpublished message, sets it to publishing and then yields it to
    # the provided block. The message is marked as readonly to prevent modifications
    # during processing. If an error occurs during the yield, the method rescues
    # the exception, sets the message status to failed, and re-raises the exception.
    # Upon successful processing, the message status is set to published.
    #
    # @yield [outboxer_messageable] Yields the polymorphically associated model.
    # @yieldparam outboxer_messageable The readonly message from outboxer.
    #
    # @raise [Outboxer::Message::NotFound] If no unpublished message is found in the queue.
    # @raise [StandardError] Reraises any exception that occurs during the yield.
    #
    # @example Publish message
    #   Outboxer::Message.publish! do |outboxer_messageable|
    #     EventHandlerWorker.perform_async({'id' => outboxer_messageable.id })
    #   end

    def self.publish!
      outboxer_message = unpublished!

      begin
        yield outboxer_message.outboxer_messageable
      rescue => exception
        failed!(id: outboxer_message.id, exception: exception)

        raise
      end

      published!(id: outboxer_message.id)
    end

    def self.unpublished!
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          outboxer_message = Models::Message
            .includes(:outboxer_messageable)
            .where(status: Models::Message::STATUS[:unpublished])
            .order(created_at: :asc)
            .limit(1)
            .lock("FOR UPDATE SKIP LOCKED")
            .first

          outboxer_message.update!(status: Models::Message::STATUS[:publishing])

          outboxer_message.outboxer_messageable.readonly!

          outboxer_message
        end
      end
    rescue ActiveRecord::RecordNotFound => exception
      raise NotFound.new(exception)
    end

    def self.published!(id:)
      ActiveRecord::Base.connection_pool.with_connection do
        outboxer_message = Models::Message
          .order(created_at: :asc)
          .lock
          .find_by!(id: id)

        if outboxer_message.status != Models::Message::STATUS[:publishing]
          raise InvalidTransition,
            "cannot transition outboxer message #{outboxer_message.id} " \
            "from #{outboxer_message.status} to (deleted)"
        end

        outboxer_message.destroy!
      end
    end

    def self.failed!(id:, exception:)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          outboxer_message = Models::Message
            .order(created_at: :asc)
            .lock
            .find_by!(id: id)

          if outboxer_message.status != Models::Message::STATUS[:publishing]
            raise InvalidTransition,
              "cannot transition outboxer message #{id} " \
              "from #{outboxer_message.status} to #{Models::Message::STATUS[:failed]}"
          end

          outboxer_message.update!(status: Models::Message::STATUS[:failed])

          outboxer_message.outboxer_exceptions.create!(
            class_name: exception.class.name,
            message_text: exception.message,
            backtrace: exception.backtrace)
        end
      end
    end

    def self.republish!(id:)
      ActiveRecord::Base.connection_pool.with_connection do
        outboxer_message = Models::Message
          .order(created_at: :asc)
          .lock
          .find_by!(id: id)

        if outboxer_message.status != Models::Message::STATUS[:failed]
          raise InvalidTransition,
            "cannot transition outboxer message #{id} " \
            "from #{outboxer_message.status} to #{Models::Message::STATUS[:failed]}"
        end

        outboxer_message.update!(status: Models::Message::STATUS[:unpublished])
      end
    end

    private_class_method :unpublished!
  end
end
