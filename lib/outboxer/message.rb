require "logger"
require "active_record"

module Outboxer
  module Message
    extend self

    class Error < Outboxer::Error; end;
    class NotFound < Error; end
    class InvalidTransition < Error; end

    def unpublished!(limit: 5, order: :asc)
      ActiveRecord::Base.connection_pool.with_connection do
        message_ids = ActiveRecord::Base.transaction do
          ids = Models::Message
            .where(status: Models::Message::STATUS[:unpublished])
            .order(created_at: order)
            .lock('FOR UPDATE SKIP LOCKED')
            .limit(limit)
            .pluck(:id)

          if !ids.empty?
            Models::Message.where(id: ids).update_all(status: Models::Message::STATUS[:publishing])
          end

          ids
        end

        Models::Message
          .where(id: message_ids, status: Models::Message::STATUS[:publishing])
          .order(created_at: order)
          .to_a
      end
    end

    def published!(id:)
      ActiveRecord::Base.connection_pool.with_connection do
        outboxer_message = Models::Message.order(created_at: :asc).lock.find_by!(id: id)

        if outboxer_message.status != Models::Message::STATUS[:publishing]
          raise InvalidTransition,
            "cannot transition outboxer message #{outboxer_message.id} " \
            "from #{outboxer_message.status} to (deleted)"
        end

        outboxer_message.destroy!

        nil
      end
    end

    def failed!(id:, exception:)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          outboxer_message = Models::Message.order(created_at: :asc).lock.find_by!(id: id)

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

          outboxer_message
        end
      end
    end

    def republish!(id:)
      ActiveRecord::Base.connection_pool.with_connection do
        outboxer_message = Models::Message.lock.find_by!(id: id)

        if outboxer_message.status != Models::Message::STATUS[:failed]
          raise InvalidTransition,
            "cannot transition outboxer message #{id} " \
            "from #{outboxer_message.status} to #{Models::Message::STATUS[:unpublished]}"
        end

        outboxer_message.update!(status: Models::Message::STATUS[:unpublished])

        outboxer_message
      end
    end
  end
end
