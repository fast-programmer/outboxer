module Outboxer
  module Message
    extend self

    Status = Models::Message::Status

    def queue(messageable: nil,
              messageable_type: nil, messageable_id: nil,
              time: ::Time)
      current_utc_time = time.now.utc

      message = Models::Message.create!(
        messageable_id: messageable&.id || messageable_id,
        messageable_type: messageable&.class&.name || messageable_type,
        status: Models::Message::Status::QUEUED,
        queued_at: current_utc_time,
        buffered_at: nil,
        publishing_at: nil,
        updated_at: current_utc_time,
        publisher_id: nil,
        publisher_name: nil)

      {
        id: message.id,
        status: message.status,
        messageable_type: message.messageable_type,
        messageable_id: message.messageable_id,
        queued_at: message.queued_at,
        buffered_at: message.buffered_at,
        publishing_at: nil,
        updated_at: message.updated_at,
      }
    end

    def find_by_id(id:)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          message = Models::Message
            .left_joins(:publisher)
            .includes(exceptions: :frames)
            .select(
              'outboxer_messages.*',
              'CASE WHEN outboxer_publishers.id IS NOT NULL THEN 1 ELSE 0 END AS publisher_exists')
            .find_by!('outboxer_messages.id = ?', id)

          {
            id: message.id,
            status: message.status,
            messageable_type: message.messageable_type,
            messageable_id: message.messageable_id,
            queued_at: message.queued_at.utc,
            buffered_at: message&.buffered_at&.utc,
            publishing_at: message&.publishing_at&.utc,
            updated_at: message.updated_at.utc,
            publisher_id: message.publisher_id,
            publisher_name: message.publisher_name,
            publisher_exists: message.publisher_exists == 1,
            exceptions: message.exceptions.map do |exception|
              {
                id: exception.id,
                class_name: exception.class_name,
                message_text: exception.message_text,
                created_at: exception.created_at.utc,
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

    def publishing(id:, publisher_id: nil, publisher_name: nil,
                   time: ::Time)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          message = Models::Message.lock.find_by!(id: id)

          if message.status != Models::Message::Status::BUFFERED
            raise ArgumentError,
              "cannot transition outboxer message #{message.id} " \
              "from #{message.status} to #{Models::Message::Status::PUBLISHING}"
          end

          current_utc_time = time.now.utc

          message.update!(
            status: Models::Message::Status::PUBLISHING,
            publishing_at: current_utc_time,
            updated_at: current_utc_time,
            publisher_id: publisher_id,
            publisher_name: publisher_name)

          {
            id: id,
            status: message.status,
            messageable_type: message.messageable_type,
            messageable_id: message.messageable_id,
            queued_at: message.queued_at,
            buffered_at: message.buffered_at,
            publishing_at: message.publishing_at,
            updated_at: message.updated_at
          }
        end
      end
    end

    def published(id:, publisher_id: nil, publisher_name: nil,
                  time: ::Time)
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
            updated_at: time.now.utc,
            publisher_id: publisher_id,
            publisher_name: publisher_name)

          {
            id: id,
            status: message.status,
            messageable_type: message.messageable_type,
            messageable_id: message.messageable_id,
            queued_at: message.queued_at,
            buffered_at: message.buffered_at,
            publishing_at: message.publishing_at,
            updated_at: message.updated_at
          }
        end
      end
    end

    def failed(id:, exception:,
               publisher_id: nil, publisher_name: nil,
               time: ::Time)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          message = Models::Message.order(queued_at: :asc).lock.find_by!(id: id)

          if message.status != Models::Message::Status::PUBLISHING
            raise ArgumentError,
              "cannot transition outboxer message #{id} " \
              "from #{message.status} to #{Models::Message::Status::FAILED}"
          end

          message.update!(
            status: Models::Message::Status::FAILED,
            updated_at: time.now.utc,
            publisher_id: publisher_id,
            publisher_name: publisher_name)

          outboxer_exception = message.exceptions.create!(
            class_name: exception.class.name, message_text: exception.message)

          exception.backtrace.each_with_index do |frame, index|
            outboxer_exception.frames.create!(index: index, text: frame)
          end

          {
            id: id,
            status: message.status,
            messageable_type: message.messageable_type,
            messageable_id: message.messageable_id,
            queued_at: message.queued_at,
            buffered_at: message.buffered_at,
            publishing_at: message.publishing_at,
            updated_at: message.updated_at
          }
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

          setting = Models::Setting.lock('FOR UPDATE').find_by(
            name: "messages.#{message.status}.count.historic")

          setting.update!(value: setting.value.to_i + 1).to_s if !setting.nil?

          { id: id }
        end
      end
    end

    REQUEUE_STATUSES = [:buffered, :publishing, :failed]

    def can_requeue?(status:)
      REQUEUE_STATUSES.include?(status&.to_sym)
    end

    def requeue(id:, publisher_id: nil, publisher_name: nil,
                time: ::Time)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          message = Models::Message.lock.find_by!(id: id)

          current_utc_time = time.now.utc

          message.update!(
            status: Models::Message::Status::QUEUED,
            queued_at: current_utc_time,
            buffered_at: nil,
            publishing_at: nil,
            updated_at: current_utc_time,
            publisher_id: publisher_id,
            publisher_name: publisher_name)

          { id: id }
        end
      end
    end
  end
end
