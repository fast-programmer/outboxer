module Outboxer
  module Messages
    extend self

    def counts_by_status
      ActiveRecord::Base.connection_pool.with_connection do
        status_counts = Models::Message::STATUSES.each_with_object({ all: 0 }) do |status, hash|
          hash[status.to_sym] = 0
        end

        Models::Message.group(:status).count.each do |status, count|
          status_counts[status.to_sym] = count
          status_counts[:all] += count
        end

        status_counts
      end
    end

    def dequeue(limit: 1, current_utc_time: Time.now.utc)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          messages = Models::Message
            .where(status: Models::Message::Status::QUEUED)
            .order(updated_at: :asc)
            .lock('FOR UPDATE SKIP LOCKED')
            .limit(limit)
            .select(:id, :messageable_type, :messageable_id)

          if messages.present?
            Models::Message
              .where(id: messages.map { |message| message[:id] })
              .update_all(updated_at: current_utc_time, status: Models::Message::Status::DEQUEUED)
          end

          messages.map do |message|
            {
              id: message.id,
              messageable_type: message.messageable_type,
              messageable_id: message.messageable_id
            }
          end
        end
      end
    end

    LIST_STATUS_OPTIONS = [nil, :queued, :dequeued, :publishing, :published, :failed]
    LIST_STATUS_DEFAULT = nil

    LIST_SORT_OPTIONS = [:id, :status, :messageable, :created_at, :updated_at]
    LIST_SORT_DEFAULT = :updated_at

    LIST_ORDER_OPTIONS = [:asc, :desc]
    LIST_ORDER_DEFAULT = :asc

    LIST_PAGE_DEFAULT = 1

    LIST_PER_PAGE_OPTIONS = [10, 100, 200, 500, 1000]
    LIST_PER_PAGE_DEFAULT = 100

    def list(status: LIST_STATUS_DEFAULT,
             sort: LIST_SORT_DEFAULT, order: LIST_ORDER_DEFAULT,
             page: LIST_PAGE_DEFAULT, per_page: LIST_PER_PAGE_DEFAULT)
      if !status.nil? && !LIST_STATUS_OPTIONS.include?(status.to_sym)
        raise ArgumentError, "status must be #{LIST_STATUS_OPTIONS.join(' ')}"
      end

      if !LIST_SORT_OPTIONS.include?(sort.to_sym)
        raise ArgumentError, "sort must be #{LIST_SORT_OPTIONS.join(' ')}"
      end

      if !LIST_ORDER_OPTIONS.include?(order.to_sym)
        raise ArgumentError, "order must be #{LIST_ORDER_OPTIONS.join(' ')}"
      end

      if !page.is_a?(Integer) || page <= 0
        raise ArgumentError, "page must be >= 1"
      end

      if !LIST_PER_PAGE_OPTIONS.include?(per_page.to_i)
        raise ArgumentError, "per_page must be #{LIST_PER_PAGE_OPTIONS.join(' ')}"
      end

      message_scope = Models::Message
      message_scope = status.nil? ? message_scope.all : message_scope.where(status: status)

      message_scope =
        if sort.to_sym == :messageable
          message_scope.order(messageable_type: order, messageable_id: order)
        else
          message_scope.order(sort => order)
        end

      messages = ActiveRecord::Base.connection_pool.with_connection do
        message_scope.page(page).per(per_page)
      end

      {
        messages: messages.map do |message|
          {
            id: message.id,
            status: message.status.to_sym,
            messageable_type: message.messageable_type,
            messageable_id: message.messageable_id,
            created_at: message.created_at.utc,
            updated_at: message.updated_at.utc
          }
        end,
        total_pages: messages.total_pages,
        current_page: messages.current_page,
        limit_value: messages.limit_value,
        total_count: messages.total_count
      }
    end

    REQUEUE_ALL_STATUSES = [:dequeued, :publishing, :failed]

    def can_requeue_all?(status:)
      REQUEUE_ALL_STATUSES.include?(status&.to_sym)
    end

    def requeue_all(status:, batch_size: 100, time: Time)
      if !can_requeue_all?(status: status)
        status_formatted = status.nil? ? 'nil' : status

        raise ArgumentError,
          "Status #{status_formatted} must be one of #{REQUEUE_ALL_STATUSES.join(', ')}"
      end

      requeued_count = 0

      loop do
        requeued_count_batch = 0

        ActiveRecord::Base.connection_pool.with_connection do
          ActiveRecord::Base.transaction do
            locked_ids = Models::Message
              .where(status: status)
              .order(updated_at: :asc)
              .limit(batch_size)
              .lock('FOR UPDATE SKIP LOCKED')
              .pluck(:id)

            requeued_count_batch = Models::Message
              .where(id: locked_ids)
              .update_all(status: Models::Message::Status::QUEUED, updated_at: time.now.utc)

            requeued_count += requeued_count_batch
          end
        end

        break if requeued_count_batch < batch_size
      end

      { requeued_count: requeued_count }
    end

    def requeue_by_ids(ids:, time: Time)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          locked_ids = Models::Message
            .where(id: ids)
            .order(updated_at: :asc)
            .lock('FOR UPDATE SKIP LOCKED')
            .pluck(:id)

          requeued_count = Models::Message
            .where(id: locked_ids)
            .update_all(status: Models::Message::Status::QUEUED, updated_at: time.now.utc)

          { requeued_count: requeued_count, not_requeued_ids: ids - locked_ids }
        end
      end
    end

    def delete_all(status: nil, batch_size: 100, older_than: nil)
      deleted_count = 0

      loop do
        deleted_count_batch = 0

        ActiveRecord::Base.connection_pool.with_connection do
          ActiveRecord::Base.transaction do
            query = Models::Message.all
            query = query.where(status: status) unless status.nil?
            query = query.where('updated_at < ?', older_than) if older_than

            locked_ids = query.order(:updated_at)
              .limit(batch_size)
              .lock('FOR UPDATE SKIP LOCKED')
              .pluck(:id)

            Models::Frame
              .joins(:exception)
              .where(exception: { message_id: locked_ids })
              .delete_all

            Models::Exception.where(message_id: locked_ids).delete_all

            deleted_count_batch = Models::Message.where(id: locked_ids).delete_all
          end
        end

        deleted_count += deleted_count_batch

        break if deleted_count_batch < batch_size
      end

      { deleted_count: deleted_count }
    end

    def delete_by_ids(ids:)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          locked_ids = Models::Message
            .where(id: ids)
            .lock('FOR UPDATE SKIP LOCKED')
            .pluck(:id)

          Models::Frame
            .joins(:exception)
            .where(exception: { message_id: locked_ids })
            .delete_all

          Models::Exception.where(message_id: locked_ids).delete_all

          deleted_count = Models::Message.where(id: locked_ids).delete_all

          { deleted_count: deleted_count, not_deleted_ids: ids - locked_ids }
        end
      end
    end
  end
end
