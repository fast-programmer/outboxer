require "logger"
require "active_record"

module Outboxer
  module Messages
    extend self

    class Error < Outboxer::Error; end;
    class InvalidTransition < Error; end

    def counts_by_status
      status_counts = Models::Message::STATUSES.each_with_object({}) do |status, hash|
        hash[status.to_s] = 0
      end

      Models::Message.group(:status).count.each do |status, count|
        status_counts[status.to_s] = count
      end

      status_counts
    end

    def unpublished!(limit: 1, order: :asc)
      ActiveRecord::Base.connection_pool.with_connection do
        message_ids = ActiveRecord::Base.transaction do
          ids = Models::Message
            .where(status: Models::Message::Status::UNPUBLISHED)
            .order(created_at: order)
            .lock('FOR UPDATE SKIP LOCKED')
            .limit(limit)
            .pluck(:id)

          if !ids.empty?
            Models::Message.where(id: ids).update_all(status: Models::Message::Status::PUBLISHING)
          end

          ids
        end

        Models::Message
          .where(id: message_ids, status: Models::Message::Status::PUBLISHING)
          .order(created_at: order)
          .to_a
      end
    end

    def republish_all_failed!
      ActiveRecord::Base.connection_pool.with_connection do
        Models::Message
          .where(status: Models::Message::Status::FAILED)
          .order(updated_at: :asc)
          .pluck(:id)
          .each_slice(1000) { |message_ids| republish_batch_failed!(message_ids) }
      end
    end

    def republish_batch_failed!(message_ids)
      ActiveRecord::Base.transaction do
        message_ids.each do |message_id|
          message = Models::Message.lock.find(message_id)

          if message.status != Models::Message::Status::FAILED
            raise InvalidTransition,
              "cannot transition outboxer message #{message.id} " \
              "from #{message.status} to #{Models::Message::Status::UNPUBLISHED}"
          end

          message.update!(status: Models::Message::Status::UNPUBLISHED)
        end
      end
    end

    def delete_all!
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          Models::Frame.delete_all
          Models::Exception.delete_all
          Models::Message.delete_all
        end
      end

      nil
    end
  end
end
