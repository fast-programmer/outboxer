require "logger"
require "active_record"

module Outboxer
  module Message
    extend self

    class Error < Outboxer::Error; end;
    class NotFound < Error; end
    class InvalidTransition < Error; end

    def published!(id:)
      ActiveRecord::Base.connection_pool.with_connection do
        outboxer_message = Models::Message.order(created_at: :asc).lock.find_by!(id: id)

        if outboxer_message.status != Models::Message::Status::PUBLISHING
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

          if outboxer_message.status != Models::Message::Status::PUBLISHING
            raise InvalidTransition,
              "cannot transition outboxer message #{id} " \
              "from #{outboxer_message.status} to #{Models::Message::Status::FAILED}"
          end

          outboxer_message.update!(status: Models::Message::Status::FAILED)

          outboxer_exception = outboxer_message.exceptions.create!(
            class_name: exception.class.name, message_text: exception.message)

          exception.backtrace.each_with_index do |frame, index|
            outboxer_exception.frames.create!(index: index, text: frame)
          end

          outboxer_message
        end
      end
    end

    def republish!(id:)
      ActiveRecord::Base.connection_pool.with_connection do
        outboxer_message = Models::Message.lock.find_by!(id: id)

        if outboxer_message.status != Models::Message::Status::FAILED
          raise InvalidTransition,
            "cannot transition outboxer message #{id} " \
            "from #{outboxer_message.status} to #{Models::Message::Status::UNPUBLISHED}"
        end

        outboxer_message.update!(status: Models::Message::Status::UNPUBLISHED)

        outboxer_message
      end
    end
  end
end
