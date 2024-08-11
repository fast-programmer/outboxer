module Outboxer
  module Message
    extend self

    Status = Models::Message::Status

    def queue(messageable: nil,
              messageable_type: nil, messageable_id: nil,
              current_utc_time: Time.now.utc)
      message = Models::Message.create!(
        messageable_id: messageable&.id || messageable_id,
        messageable_type: messageable&.class&.name || messageable_type,
        status: Models::Message::Status::QUEUED,
        created_at: current_utc_time,
        updated_at: current_utc_time)

      { id: message.id }
    end

    def find_by_id(id:)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          message = Models::Message.includes(exceptions: :frames).find_by!(id: id)

          {
            id: message.id,
            status: message.status,
            messageable_type: message.messageable_type,
            messageable_id: message.messageable_id,
            created_at: message.created_at.utc.to_s,
            updated_at: message.updated_at.utc.to_s,
            exceptions: message.exceptions.map do |exception|
              {
                id: exception.id,
                class_name: exception.class_name,
                message_text: exception.message_text,
                created_at: exception.created_at.utc.to_s,
                frames: exception.frames.map do |frame|
                  {
                    id: frame.id,
                    index: frame.index,
                    text: frame.text
                  }
                end
              }
            end
          }
        end
      end
    end

    def publishing(id:, current_utc_time: Time.now.utc)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          message = Models::Message.lock.find_by!(id: id)

          if message.status != Models::Message::Status::DEQUEUED
            raise ArgumentError,
              "cannot transition outboxer message #{message.id} " \
              "from #{message.status} to #{Models::Message::Status::PUBLISHING}"
          end

          message.update!(
            status: Models::Message::Status::PUBLISHING,
            updated_at: current_utc_time)

          {
            id: id,
            status: message.status,
            messageable_type: message.messageable_type,
            messageable_id: message.messageable_id
          }
        end
      end
    end

    def published(id:, current_utc_time: Time.now.utc)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          message = Models::Message.lock.find_by!(id: id)

          if message.status != Models::Message::Status::PUBLISHING
            raise ArgumentError,
              "cannot transition outboxer message #{message.id} " \
              "from #{message.status} to published"
          end

          message.update!(
            status: Models::Message::Status::PUBLISHED,
            updated_at: current_utc_time)

          {
            id: id,
            status: message.status,
            messageable_type: message.messageable_type,
            messageable_id: message.messageable_id
          }
        end
      end
    end

    def failed(id:, exception:, current_utc_time: Time.now.utc)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          message = Models::Message.order(created_at: :asc).lock.find_by!(id: id)

          if message.status != Models::Message::Status::PUBLISHING
            raise ArgumentError,
              "cannot transition outboxer message #{id} " \
              "from #{message.status} to #{Models::Message::Status::FAILED}"
          end

          message.update!(
            status: Models::Message::Status::FAILED,
            updated_at: current_utc_time)

          outboxer_exception = message.exceptions.create!(
            class_name: exception.class.name, message_text: exception.message)

          exception.backtrace.each_with_index do |frame, index|
            outboxer_exception.frames.create!(index: index, text: frame)
          end

          { id: id }
        end
      end
    end

    def delete(id:)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          message = Models::Message.includes(exceptions: :frames).lock.find_by!(id: id)

          message.exceptions.each { |exception| exception.frames.each(&:delete) }
          message.exceptions.delete_all
          message.delete

          if message.status == Status::PUBLISHED
            metric = Outboxer::Models::Metric
              .lock('FOR UPDATE')
              .find_by!(name: 'messages.published.count.historic')

            metric.update!(value: metric.value + 1)
          end

          { id: id }
        end
      end
    end

    def requeue(id:, current_utc_time: Time.now.utc)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          message = Models::Message.lock.find_by!(id: id)

          message.update!(status: Models::Message::Status::QUEUED, updated_at: current_utc_time)

          { id: id }
        end
      end
    end
  end
end
