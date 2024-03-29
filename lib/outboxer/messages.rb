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

    def list(status: nil, sort: :updated_at, order: :asc, page: 1, per_page: 100)
      if !status.nil? && !Models::Message::STATUSES.include?(status.to_s)
        raise ArgumentError, "status must be #{Models::Message::STATUSES.join(' ')}"
      end

      sort_options = [:id, :status, :messageable, :created_at, :updated_at]
      if !sort_options.include?(sort.to_sym)
        raise ArgumentError, "sort must be #{sort_options.join(' ')}"
      end

      order_options = [:asc, :desc]
      if !order_options.include?(order.to_sym)
        raise ArgumentError, "order must be #{order_options.join(' ')}"
      end

      if !page.is_a?(Integer) || page <= 0
        raise ArgumentError, "page must be >= 1"
      end

      per_page_options = [100, 200, 500, 1000]
      if !per_page_options.include?(per_page)
        raise ArgumentError, "per_page must be #{per_page_options.join(' ')}"
      end

      message_scope = Models::Message
      message_scope = status.nil? ? message_scope.all : message_scope.where(status: status)

      message_scope =
        if sort.to_sym == :messageable
          message_scope.order(messageable_type: order.to_sym, messageable_id: order.to_sym)
        else
          message_scope.order(sort.to_sym => order.to_sym)
        end

      messages = ActiveRecord::Base.connection_pool.with_connection do
        message_scope.page(page).per(per_page)
      end

      messages.map do |message|
        {
          'id' => message.id,
          'status' => message.status,
          'messageable' => "#{message.messageable_type}::#{message.messageable_id}",
          'created_at' => message.created_at.utc.to_s,
          'updated_at' => message.updated_at.utc.to_s
        }
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
