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
          ids = Models::Message
            .where(status: Models::Message::Status::BACKLOGGED)
            .order(updated_at: :asc)
            .lock('FOR UPDATE SKIP LOCKED')
            .limit(limit)
            .pluck(:id)

          if ids.present?
            updated_rows = Models::Message
              .where(id: ids)
              .update_all(updated_at: Time.current, status: Models::Message::Status::QUEUED)

            if updated_rows != ids.size
              raise Error,
                'The number of updated messages does not match the expected number of ids.'
            end

            ids.map { |id| { id: id } }
          else
            []
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

    def republish_all(batch_size: 100)
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

            updated_count = locked_ids.empty? ? 0 : Models::Message
              .where(id: locked_ids)
              .update_all(
                status: Models::Message::Status::BACKLOGGED,
                updated_at: DateTime.now.utc)
          end

          updated_total_count += updated_count

          break if updated_count < batch_size
        end
      end

      { count: updated_total_count }
    end

    def republish_selected(ids:)
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
            status: Models::Message::Status::BACKLOGGED, updated_at: DateTime.now.utc)
        end
      end

      { count: updated_count }
    end

    def delete_all(batch_size: 100)
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

      { count: deleted_total_count }
    end

    def delete_selected(ids:)
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

      { count: deleted_count }
    end
  end
end
