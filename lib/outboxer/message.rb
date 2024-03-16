require "logger"
require "active_record"

module Outboxer
  module Message
    extend self

    class Error < Outboxer::Error; end;
    class NotFound < Error; end
    class InvalidTransition < Error; end

    def find_by_id!(id:)
      message = Models::Message.includes(exceptions: :frames).find_by!(id: id)

      {
        'id' => message.id,
        'status' => message.status,
        'messageable' => "#{message.messageable_type}::#{message.messageable_id}",
        'created_at' => message.created_at.utc.to_s,
        'updated_at' => message.updated_at.utc.to_s,
        'exceptions' => message.exceptions.map do |exception|
          {
            'id' => exception.id,
            'class_name' => exception.class_name,
            'message_text' => exception.message_text,
            'created_at' => exception.created_at.utc.to_s,
            'frames' => exception.frames.map do |frame|
              {
                'id' => frame.id,
                'index' => frame.index,
                'text' => frame.text
              }
            end
          }
        end
      }
    rescue ActiveRecord::RecordNotFound
      raise NotFound, "Couldn't find Outboxer::Models::Message with id #{id}"
    end

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

    def delete!(id:)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          outboxer_message = Models::Message.includes(exceptions: :frames).find_by!(id: id)

          outboxer_message.exceptions.each { |exception| exception.frames.destroy_all }
          outboxer_message.exceptions.destroy_all
          outboxer_message.destroy
        end
      end

      { 'id' => id }
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
