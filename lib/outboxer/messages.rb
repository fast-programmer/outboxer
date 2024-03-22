require "logger"
require "active_record"

module Outboxer
  module Messages
    extend self

    class Error < Outboxer::Error; end;
    class InvalidTransition < Error; end

    def counts_by_status
      ActiveRecord::Base.connection_pool.with_connection do
        status_counts = Models::Message::STATUSES.each_with_object({}) do |status, hash|
          hash[status.to_s] = 0
        end

        Models::Message.group(:status).count.each do |status, count|
          status_counts[status.to_s] = count
        end

        status_counts
      end
    end

    def unpublished!(limit: 1, order: :asc)
      ActiveRecord::Base.connection_pool.with_connection do
        ids = []

        ActiveRecord::Base.transaction do
          ids = Models::Message
            .where(status: Models::Message::Status::UNPUBLISHED)
            .order(created_at: order)
            .lock('FOR UPDATE SKIP LOCKED')
            .limit(limit)
            .pluck(:id)

          Models::Message.where(id: ids).update_all(status: Models::Message::Status::PUBLISHING)
        end

        Models::Message
          .where(id: ids, status: Models::Message::Status::PUBLISHING)
          .order(created_at: order)
          .to_a
      end
    end

    def republish_all!(batch_size: 100)
      updated_total_count = 0

      ActiveRecord::Base.connection_pool.with_connection do
        updated_count = 0

        loop do
          ActiveRecord::Base.transaction do
            locked_ids = Models::Message
              .where(status: Models::Message::Status::FAILED)
              .order(updated_at: :asc)
              .limit(batch_size)
              .lock('FOR UPDATE')
              .pluck(:id)

            updated_count = Models::Message.where(id: locked_ids).update_all(
              status: Models::Message::Status::UNPUBLISHED, updated_at: DateTime.now.utc)
          end

          updated_total_count += updated_count

          break if updated_count < batch_size
        end
      end

      { 'count' => updated_total_count }
    end

    def republish_selected!(ids:)
      updated_count = 0

      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          locked_ids = Models::Message
            .where(id: ids, status: Models::Message::Status::FAILED)
            .order(updated_at: :asc)
            .lock('FOR UPDATE')
            .pluck(:id)

          missing_ids = ids - locked_ids
          if missing_ids.any?
            raise NotFound, "Some IDs could not be found: #{missing_ids.join(', ')}"
          end

          updated_count = Models::Message.where(id: locked_ids).update_all(
            status: Models::Message::Status::UNPUBLISHED, updated_at: DateTime.now.utc)
        end
      end

      { 'count' => updated_count }
    end

    def delete_all!(batch_size: 100)
      deleted_total_count = 0

      ActiveRecord::Base.connection_pool.with_connection do
        loop do
          deleted_count = 0

          ActiveRecord::Base.transaction do
            locked_ids = Models::Message
              .order(:updated_at).limit(batch_size).lock('FOR UPDATE').pluck(:id)

            Models::Frame
              .joins(:exception)
              .where(exception: { message_id: locked_ids })
              .delete_all

            Models::Exception.where(message_id: locked_ids).delete_all

            deleted_count = Models::Message.where(id: locked_ids).delete_all
          end

          deleted_total_count += deleted_count

          break if deleted_count < batch_size
        end
      end

      { 'count' => deleted_total_count }
    end

    def delete_selected!(ids:)
      deleted_count = 0

      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          locked_ids = Models::Message.where(id: ids).lock('FOR UPDATE').pluck(:id)

          missing_ids = ids - locked_ids
          if missing_ids.any?
            raise NotFound, "Some IDs could not be found: #{missing_ids.join(', ')}"
          end

          Models::Frame
            .joins(:exception)
            .where(exception: { message_id: locked_ids })
            .delete_all

          Models::Exception.where(message_id: locked_ids).delete_all

          deleted_count = Models::Message.where(id: locked_ids).delete_all
        end
      end

      { 'count' => deleted_count }
    end
  end
end
