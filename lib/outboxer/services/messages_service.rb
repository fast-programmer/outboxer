module Outboxer
  module MessagesService
    module_function

    def buffer(limit: 1, publisher_id: nil, publisher_name: nil,
               time: ::Time)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          messages = Message
            .where(status: Message::Status::QUEUED)
            .order(updated_at: :asc)
            .lock("FOR UPDATE SKIP LOCKED")
            .limit(limit)
            .select(:id, :messageable_type, :messageable_id, :queued_at)

          current_utc_time = time.now.utc

          if messages.present?
            Message
              .where(id: messages.map { |message| message[:id] })
              .update_all(
                status: Message::Status::BUFFERED,
                buffered_at: current_utc_time,
                updated_at: current_utc_time,
                publisher_id: publisher_id,
                publisher_name: publisher_name)
          end

          messages.map do |message|
            {
              id: message.id,
              status: Message::Status::BUFFERED,
              messageable_type: message.messageable_type,
              messageable_id: message.messageable_id,
              queued_at: message.queued_at,
              buffered_at: current_utc_time,
              publishing_at: nil,
              updated_at: current_utc_time
            }
          end
        end
      end
    end

    LIST_STATUS_OPTIONS = [nil, :queued, :buffered, :publishing, :published, :failed]
    LIST_STATUS_DEFAULT = nil

    LIST_SORT_OPTIONS = [:id, :status, :messageable, :queued_at, :updated_at, :publisher_name]
    LIST_SORT_DEFAULT = :updated_at

    LIST_ORDER_OPTIONS = [:asc, :desc]
    LIST_ORDER_DEFAULT = :asc

    LIST_PAGE_DEFAULT = 1

    LIST_PER_PAGE_OPTIONS = [10, 100, 200, 500, 1000]
    LIST_PER_PAGE_DEFAULT = 100

    LIST_TIME_ZONE_OPTIONS = (ActiveSupport::TimeZone.all.map(&:tzinfo).map(&:name) + ["UTC"]).sort
    LIST_TIME_ZONE_DEFAULT = "UTC"

    def list(status: LIST_STATUS_DEFAULT,
             sort: LIST_SORT_DEFAULT, order: LIST_ORDER_DEFAULT,
             page: LIST_PAGE_DEFAULT, per_page: LIST_PER_PAGE_DEFAULT,
             time_zone: LIST_TIME_ZONE_DEFAULT)
      if !status.nil? && !LIST_STATUS_OPTIONS.include?(status.to_sym)
        raise ArgumentError, "status must be #{LIST_STATUS_OPTIONS.join(" ")}"
      end

      if !LIST_SORT_OPTIONS.include?(sort.to_sym)
        raise ArgumentError, "sort must be #{LIST_SORT_OPTIONS.join(" ")}"
      end

      if !LIST_ORDER_OPTIONS.include?(order.to_sym)
        raise ArgumentError, "order must be #{LIST_ORDER_OPTIONS.join(" ")}"
      end

      raise ArgumentError, "page must be >= 1" if !page.is_a?(Integer) || page <= 0

      if !LIST_PER_PAGE_OPTIONS.include?(per_page.to_i)
        raise ArgumentError, "per_page must be #{LIST_PER_PAGE_OPTIONS.join(" ")}"
      end

      raise ArgumentError, "time_zone must be valid" if !LIST_TIME_ZONE_OPTIONS.include?(time_zone)

      base_scope = Message.left_joins(:publisher)
      base_scope = if status.nil?
                     base_scope.all
                   else
                     base_scope.where("outboxer_messages.status = ?", status)
                   end

      total_count = base_scope.count

      sorted_scope = case sort.to_sym
                     when :messageable
                       base_scope.order(messageable_type: order, messageable_id: order)
                     else
                       base_scope.order(sort => order)
                     end

      offset = (page - 1) * per_page
      paginated_messages = sorted_scope
        .select(
          "outboxer_messages.*",
          "CASE WHEN outboxer_publishers.id IS NOT NULL THEN 1 ELSE 0 END AS publisher_exists")
        .offset(offset).limit(per_page)

      total_pages = (total_count.to_f / per_page).ceil

      {
        messages: paginated_messages.map do |message|
          {
            id: message.id,
            status: message.status.to_sym,
            messageable_type: message.messageable_type,
            messageable_id: message.messageable_id,
            queued_at: message.queued_at.utc.in_time_zone(time_zone),
            buffered_at: message&.buffered_at&.utc&.in_time_zone(time_zone),
            publishing_at: message&.publishing_at&.utc&.in_time_zone(time_zone),
            updated_at: message.updated_at.utc.in_time_zone(time_zone),
            publisher_id: message.publisher_id,
            publisher_name: message.publisher_name,
            publisher_exists: message.publisher_exists == 1
          }
        end,
        total_pages: total_pages,
        current_page: page,
        limit_value: per_page,
        total_count: total_count
      }
    end

    REQUEUE_STATUSES = [:buffered, :publishing, :failed]

    def can_requeue?(status:)
      REQUEUE_STATUSES.include?(status&.to_sym)
    end

    def requeue_all(status:, batch_size: 100, time: ::Time,
                    publisher_id: nil, publisher_name: nil)
      if !can_requeue?(status: status)
        status_formatted = status.nil? ? "nil" : status

        raise ArgumentError,
          "Status #{status_formatted} must be one of #{REQUEUE_STATUSES.join(", ")}"
      end

      requeued_count = 0

      loop do
        requeued_count_batch = 0

        ActiveRecord::Base.connection_pool.with_connection do
          ActiveRecord::Base.transaction do
            locked_ids = Message
              .where(status: status)
              .order(updated_at: :asc)
              .limit(batch_size)
              .lock("FOR UPDATE SKIP LOCKED")
              .pluck(:id)

            current_utc_time = time.now.utc

            requeued_count_batch = Message
              .where(id: locked_ids)
              .update_all(
                status: Message::Status::QUEUED,
                queued_at: current_utc_time,
                buffered_at: nil,
                publishing_at: nil,
                updated_at: current_utc_time,
                publisher_id: publisher_id,
                publisher_name: publisher_name)

            requeued_count += requeued_count_batch
          end
        end

        break if requeued_count_batch < batch_size
      end

      { requeued_count: requeued_count }
    end

    def requeue_by_ids(ids:, publisher_id: nil, publisher_name: nil, time: Time)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          locked_ids = Message
            .where(id: ids)
            .order(updated_at: :asc)
            .lock("FOR UPDATE SKIP LOCKED")
            .pluck(:id)

          requeued_count = Message
            .where(id: locked_ids)
            .update_all(
              status: Message::Status::QUEUED,
              updated_at: time.now.utc,
              publisher_id: publisher_id,
              publisher_name: publisher_name)

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
            query = Message.all
            query = query.where(status: status) unless status.nil?
            query = query.where("updated_at < ?", older_than) if older_than
            messages = query.order(:updated_at)
              .limit(batch_size)
              .lock("FOR UPDATE SKIP LOCKED")
              .pluck(:id, :status)
              .map { |message_id, message_status| { id: message_id, status: message_status } }

            message_ids = messages.map { |message| message[:id] }

            Frame
              .joins(:exception)
              .where(exception: { message_id: message_ids })
              .delete_all

            Exception.where(message_id: message_ids).delete_all

            deleted_count_batch = Message.where(id: message_ids).delete_all

            [
              MessageService::Status::PUBLISHED,
              MessageService::Status::FAILED
            ].each do |message_status|
              current_messages = messages.select { |message| message[:status] == message_status }

              if current_messages.count > 0
                setting_name = "messages.#{message_status}.count.historic"
                setting = Setting.lock("FOR UPDATE").find_by!(name: setting_name)
                setting.update!(value: setting.value.to_i + current_messages.count).to_s
              end
            end
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
          messages = Message
            .where(id: ids)
            .lock("FOR UPDATE SKIP LOCKED")
            .pluck(:id, :status)
            .map { |id, status| { id: id, status: status } }

          message_ids = messages.map { |message| message[:id] }

          Frame
            .joins(:exception)
            .where(exception: { message_id: message_ids })
            .delete_all

          Exception.where(message_id: message_ids).delete_all

          deleted_count = Message.where(id: message_ids).delete_all

          [MessageService::Status::PUBLISHED, MessageService::Status::FAILED].each do |status|
            current_messages = messages.select { |message| message[:status] == status }

            if current_messages.count > 0
              setting_name = "messages.#{status}.count.historic"
              setting = Setting.lock("FOR UPDATE").find_by!(name: setting_name)
              setting.update!(value: setting.value.to_i + current_messages.count).to_s
            end
          end

          { deleted_count: deleted_count, not_deleted_ids: ids - message_ids }
        end
      end
    end

    def metrics(time: ::Time)
      metrics = { all: { count: { current: 0 } } }

      Message::STATUSES.each do |status|
        metrics[status.to_sym] = { count: { current: 0 }, latency: 0, throughput: 0 }
      end

      grouped_messages = nil

      current_utc_time = time.now.utc

      ActiveRecord::Base.connection_pool.with_connection do
        time_condition = ActiveRecord::Base.sanitize_sql_array([
          "updated_at >= ?", current_utc_time - 1.second
        ])

        grouped_messages = Message
          .group(:status)
          .select(
            "status, COUNT(*) AS count, MIN(updated_at) AS oldest_updated_at",
            "SUM(CASE WHEN #{time_condition} THEN 1 ELSE 0 END) AS throughput")
          .to_a

        metrics[:published][:count][:historic] = Setting
          .find_by!(name: "messages.published.count.historic").value.to_i

        metrics[:failed][:count][:historic] = Setting
          .find_by!(name: "messages.failed.count.historic").value.to_i
      end

      grouped_messages.each do |grouped_message|
        status = grouped_message.status.to_sym

        metrics[status][:count][:current] = grouped_message.count

        if grouped_message.oldest_updated_at
          latency = (current_utc_time - grouped_message.oldest_updated_at.utc).to_i

          metrics[status][:latency] = latency
        end

        metrics[status][:throughput] = grouped_message.throughput

        metrics[:all][:count][:current] += grouped_message.count
      end

      metrics[:published][:count][:total] =
        metrics[:published][:count][:historic] + metrics[:published][:count][:current]

      metrics[:failed][:count][:total] =
        metrics[:failed][:count][:historic] + metrics[:failed][:count][:current]

      metrics
    end
  end
end
