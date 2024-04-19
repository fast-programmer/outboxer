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

    def queue(limit: 1)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          messages = Models::Message
            .where(status: Models::Message::Status::BACKLOGGED)
            .order(updated_at: :asc)
            .lock('FOR UPDATE SKIP LOCKED')
            .limit(limit)
            .select(:id, :messageable_type, :messageable_id)

          if messages.present?
            Models::Message
              .where(id: messages.map { |message| message[:id] })
              .update_all(updated_at: Time.current, status: Models::Message::Status::QUEUED)
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

    STATUS = nil
    SORT = :updated_at
    ORDER = :asc
    PAGE = 1
    PER_PAGE = 10

    def backlogged(sort: SORT, order: ORDER, page: PAGE, per_page: PER_PAGE)
      list(status: Models::Message::Status::BACKLOGGED)
    end

    def queued(sort: SORT, order: ORDER, page: PAGE, per_page: PER_PAGE)
      list(status: Models::Message::Status::QUEUED)
    end

    def publishing(sort: SORT, order: ORDER, page: PAGE, per_page: PER_PAGE)
      list(status: Models::Message::Status::PUBLISHING)
    end

    def failed(sort: SORT, order: ORDER, page: PAGE, per_page: PER_PAGE)
      list(status: Models::Message::Status::FAILED)
    end

    def list(status: STATUS, sort: SORT, order: ORDER, page: PAGE, per_page: PER_PAGE)
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

      per_page_options = [10, 100, 200, 500, 1000]
      if !per_page_options.include?(per_page.to_i)
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

      {
        data: messages.map do |message|
          {
            id: message.id,
            status: message.status,
            messageable_type: message.messageable_type,
            messageable_id: message.messageable_id,
            created_at: message.created_at.utc.to_s,
            updated_at: message.updated_at.utc.to_s
          }
        end,
        total_pages: messages.total_pages,
        current_page: messages.current_page,
        limit_value: messages.limit_value,
        total_count: messages.total_count
      }
    end

    def republish_all_failed(batch_size: 100)
      republished_count = 0

      loop do
        republished_count_batch = 0

        ActiveRecord::Base.connection_pool.with_connection do
          ActiveRecord::Base.transaction do
            locked_ids = Models::Message
              .where(status: Models::Message::Status::FAILED)
              .order(updated_at: :asc)
              .limit(batch_size)
              .lock('FOR UPDATE SKIP LOCKED')
              .pluck(:id)

            republished_count_batch = Models::Message
              .where(id: locked_ids)
              .update_all(status: Models::Message::Status::BACKLOGGED, updated_at: DateTime.now.utc)

            republished_count += republished_count_batch
          end
        end

        break if republished_count_batch < batch_size
      end

      { republished_count: republished_count }
    end

    def republish_selected(ids:)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          locked_ids = Models::Message
            .where(id: ids)
            .order(updated_at: :asc)
            .lock('FOR UPDATE SKIP LOCKED')
            .pluck(:id)

          republished_count = Models::Message
            .where(id: locked_ids)
            .update_all(status: Models::Message::Status::BACKLOGGED, updated_at: DateTime.now.utc)

          { republished_count: republished_count, not_republished_ids: ids - locked_ids }
        end
      end
    end

    def delete_all_failed(batch_size: 100)
      deleted_count = 0

      loop do
        deleted_count_batch = 0

        ActiveRecord::Base.connection_pool.with_connection do
          ActiveRecord::Base.transaction do
            locked_ids = Models::Message
              .where(status: Models::Message::Status::FAILED)
              .order(:updated_at)
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

    def delete_selected(ids:)
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
