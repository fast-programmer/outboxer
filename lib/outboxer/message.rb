module Outboxer
  # Message lifecycle management including queuing, buffering, and publishing of messages.
  module Message
    module_function

    Status = Models::Message::Status

    # Queues a new message.
    # @param messageable [Object, nil] the object associated with the message.
    # @param time [Time] time context for setting timestamps.
    # @return [Hash] a hash with message details including IDs and timestamps.
    def queue(messageable:, time: ::Time)
      current_utc_time = time.now.utc

      message = Models::Message.create!(
        status: Message::Status::QUEUED,
        messageable_id: messageable.id,
        messageable_type: messageable.class.name,
        updated_at: current_utc_time,
        queued_at: current_utc_time)

      serialize(
        id: message.id,
        status: message.status,
        messageable_type: message.messageable_type,
        messageable_id: message.messageable_id,
        updated_at: message.updated_at)
    end

    # Marks queued messages as buffered.
    #
    # @param limit [Integer] the number of messages to buffer.
    # @param publisher_id [Integer, nil] the ID of the publisher.
    # @param publisher_name [String, nil] the name of the publisher.
    # @param time [Time] current time context used to update timestamps.
    # @return [Array<Hash>] details of buffered messages.
    def buffer(limit: 1, publisher_id: nil, publisher_name: nil, time: ::Time)
      current_utc_time = time.now.utc
      messages = []

      # logger = Outboxer::Logger.new($stdout)

      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          messages = Models::Message
            .where(status: Message::Status::QUEUED)
            .order(updated_at: :asc)
            .limit(limit)
            .lock("FOR UPDATE SKIP LOCKED")
            .pluck(:id, :messageable_type, :messageable_id)

          message_ids = messages.map(&:first)

          # logger.info("[outboxer] .buffer > locked message ids #{message_ids.inspect}")

          updated_rows = Models::Message
            .where(id: message_ids, status: Message::Status::QUEUED)
            .update_all(
              status: Message::Status::BUFFERED,
              updated_at: current_utc_time,
              buffered_at: current_utc_time,
              publisher_id: publisher_id,
              publisher_name: publisher_name)

          raise ArgumentError, "Some messages not buffered" if updated_rows != message_ids.size
        end
      end

      # logger.info("[outboxer] .buffer > unlocked message ids #{ids.inspect}")

      messages.map do |(id, type, mid)|
        serialize(
          id: id,
          status: Message::Status::BUFFERED,
          messageable_type: type,
          messageable_id: mid,
          updated_at: current_utc_time)
      end
    end

    # Marks buffered messages as publishing.
    #
    # @param ids [Array<Integer>] message IDs to mark as publishing.
    # @param publisher_id [Integer, nil] optional publisher ID.
    # @param publisher_name [String, nil] optional publisher name.
    # @param time [Time] a time-like object (e.g. Time) for consistent UTC timestamps.
    # @return [Array<Hash>] serialized messages with updated publishing status.
    # @raise [ArgumentError] if any given message is not in buffered state.
    def publishing_by_ids(ids:, publisher_id: nil, publisher_name: nil, time: ::Time)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          messages = Models::Message
            .where(status: Status::BUFFERED, id: ids)
            .lock("FOR UPDATE")
            .to_a

          raise ArgumentError, "Some messages not buffered" if messages.size != ids.size

          current_utc_time = time.now.utc

          Models::Message
            .where(status: Status::BUFFERED, id: ids)
            .update_all(
              status: Status::PUBLISHING,
              updated_at: current_utc_time,
              publishing_at: current_utc_time,
              publisher_id: publisher_id,
              publisher_name: publisher_name)

          messages.map do |message|
            Message.serialize(
              id: message.id,
              status: Status::PUBLISHING,
              messageable_type: message.messageable_type,
              messageable_id: message.messageable_id,
              updated_at: current_utc_time,
              publisher_id: publisher_id,
              publisher_name: publisher_name)
          end
        end
      end
    end

    # Marks publishing messages as published.
    #
    # @param ids [Array<Integer>] message IDs to mark as published.
    # @param publisher_id [Integer, nil] optional publisher ID.
    # @param publisher_name [String, nil] optional publisher name.
    # @param time [Time] a time-like object used to determine the current UTC timestamp.
    # @return [Array<Hash>] serialized messages with updated published status.
    # @raise [ArgumentError] if any given message is not in publishing state.
    def published_by_ids(ids:, publisher_id: nil, publisher_name: nil, time: ::Time)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          messages = Models::Message
            .where(status: Status::PUBLISHING, id: ids)
            .lock("FOR UPDATE")
            .to_a

          raise ArgumentError, "Some messages not publishing" if messages.size != ids.size

          current_utc_time = time.now.utc

          Models::Message
            .where(status: Status::PUBLISHING, id: ids)
            .update_all(
              status: Status::PUBLISHED,
              updated_at: current_utc_time,
              published_at: current_utc_time,
              publisher_id: publisher_id,
              publisher_name: publisher_name)

          messages.map do |message|
            Message.serialize(
              id: message.id,
              status: Status::PUBLISHED,
              messageable_type: message.messageable_type,
              messageable_id: message.messageable_id,
              updated_at: current_utc_time,
              publisher_id: publisher_id,
              publisher_name: publisher_name)
          end
        end
      end
    end

    # Marks publishing messages as failed and logs the exception details.
    #
    # @param ids [Array<Integer>] message IDs to mark as failed.
    # @param exception [Exception] the exception that caused the failure.
    # @param publisher_id [Integer, nil] optional publisher ID.
    # @param publisher_name [String, nil] optional publisher name.
    # @param time [Time] a time-like object used to determine the current UTC timestamp.
    # @return [Array<Hash>] serialized messages with updated failed status.
    # @raise [ArgumentError] if any given message is not in publishing state.
    def failed_by_ids(ids:, exception:, publisher_id: nil, publisher_name: nil, time: ::Time)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          messages = Models::Message
            .where(status: Status::PUBLISHING, id: ids)
            .lock("FOR UPDATE")
            .to_a

          raise ArgumentError, "Some messages not publishing" if messages.size != ids.size

          current_utc_time = time.now.utc

          Models::Message
            .where(status: Status::PUBLISHING, id: ids)
            .update_all(
              status: Status::FAILED,
              updated_at: current_utc_time,
              failed_at: current_utc_time,
              publisher_id: publisher_id,
              publisher_name: publisher_name)

          messages.each do |message|
            outboxer_exception = message.exceptions.create!(
              class_name: exception.class.name,
              message_text: exception.message)

            exception.backtrace.each_with_index do |frame, index|
              outboxer_exception.frames.create!(index: index, text: frame)
            end
          end

          messages.map do |message|
            Message.serialize(
              id: message.id,
              status: Status::FAILED,
              messageable_type: message.messageable_type,
              messageable_id: message.messageable_id,
              updated_at: current_utc_time)
          end
        end
      end
    end

    # Serializes message attributes into a hash.
    #
    # @param id [Integer] message ID.
    # @param status [String] message status.
    # @param messageable_type [String] type of the messageable entity.
    # @param messageable_id [String] ID of the messageable entity.
    # @param updated_at [Time] the timestamp of last update.
    # @param queued_at [Time, nil] optional timestamp when message was queued.
    # @param buffered_at [Time, nil] optional timestamp when message was buffered.
    # @param publishing_at [Time, nil] optional timestamp when message was marked publishing.
    # @param published_at [Time, nil] optional timestamp when message was marked published.
    # @param failed_at [Time, nil] optional timestamp when message was marked failed.
    # @param publisher_id [Integer, nil] optional publisher ID.
    # @param publisher_name [String, nil] optional publisher name.
    # @return [Hash] serialized message details.
    def serialize(id:, status:, messageable_type:, messageable_id:, updated_at:,
                  queued_at: nil, buffered_at: nil,
                  publishing_at: nil, published_at: nil, failed_at: nil,
                  publisher_id: nil, publisher_name: nil)
      {
        id: id,
        status: status,
        messageable_type: messageable_type,
        messageable_id: messageable_id,
        updated_at: updated_at,
        queued_at: queued_at,
        buffered_at: buffered_at,
        publishing_at: publishing_at,
        published_at: published_at,
        failed_at: failed_at,
        publisher_id: publisher_id,
        publisher_name: publisher_name
      }
    end

    # Finds a message by ID, including details about related publishers and exceptions.
    # @param id [Integer] the ID of the message to find.
    # @return [Hash] detailed information about the message.
    def find_by_id(id:)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          message = Models::Message
            .left_joins(:publisher)
            .includes(exceptions: :frames)
            .select(
              "outboxer_messages.*",
              "CASE WHEN outboxer_publishers.id IS NOT NULL THEN 1 ELSE 0 END AS publisher_exists")
            .find_by!("outboxer_messages.id = ?", id)

          {
            id: message.id,
            status: message.status,
            messageable_type: message.messageable_type,
            messageable_id: message.messageable_id,
            updated_at: message.updated_at.utc,
            queued_at: message.queued_at.utc,
            buffered_at: message&.buffered_at&.utc, # TODO: is &.buffered_at necessary?
            publishing_at: message&.publishing_at&.utc,
            published_at: message&.published_at&.utc,
            failed_at: message&.failed_at&.utc,
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

    # Deletes a message by ID.
    # @param id [Integer] the ID of the message to delete.
    # @return [Hash] details of the deleted message.
    def delete(id:)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          message = Models::Message.includes(exceptions: :frames).lock.find_by!(id: id)

          message.exceptions.each { |exception| exception.frames.each(&:delete) }
          message.exceptions.delete_all
          message.delete

          setting = Models::Setting.lock("FOR UPDATE").find_by(
            name: "messages.#{message.status}.count.historic")

          setting.update!(value: setting.value.to_i + 1).to_s if !setting.nil?

          { id: id }
        end
      end
    end

    REQUEUE_STATUSES = [:buffered, :publishing, :failed]

    # Determines if a message in a certain status can be requeued.
    # @param status [Symbol] the status to check.
    # @return [Boolean] true if the message can be requeued, false otherwise.
    def can_requeue?(status:)
      REQUEUE_STATUSES.include?(status&.to_sym)
    end

    # Requeues a message by updating its status to queued.
    # @param id [Integer] the ID of the message to requeue.
    # @param publisher_id [Integer, nil] the ID of the publisher.
    # @param publisher_name [String, nil] the name of the publisher.
    # @param time [Time] current time context used to update timestamps.
    # @return [Hash] updated message details.
    def requeue(id:, publisher_id: nil, publisher_name: nil,
                time: ::Time)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          message = Models::Message.lock.find_by!(id: id)

          current_utc_time = time.now.utc

          message.update!(
            status: Message::Status::QUEUED,
            updated_at: current_utc_time,
            queued_at: current_utc_time,
            buffered_at: nil,
            publishing_at: nil,
            published_at: nil,
            failed_at: nil,
            publisher_id: publisher_id,
            publisher_name: publisher_name)

          { id: id }
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

    # Lists messages based on given criteria and pagination settings.
    # @param status [Symbol, nil] filter by message status.
    # @param sort [Symbol] sort order field.
    # @param order [Symbol] sort direction, either :asc or :desc.
    # @param page [Integer] page number.
    # @param per_page [Integer] number of items per page.
    # @param time_zone [String] time zone to use for datetime fields.
    # @return [Hash] paginated message details including total pages and counts.
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

      base_scope = Models::Message.left_joins(:publisher)
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
            updated_at: message.updated_at.utc.in_time_zone(time_zone),
            queued_at: message.queued_at.utc.in_time_zone(time_zone),
            buffered_at: message&.buffered_at&.utc&.in_time_zone(time_zone),
            publishing_at: message&.publishing_at&.utc&.in_time_zone(time_zone),
            published_at: message&.published_at&.utc&.in_time_zone(time_zone),
            failed_at: message&.failed_at&.utc&.in_time_zone(time_zone),
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

    # Checks if all messages with a specific status can be requeued.
    # @param status [Symbol] the status to check for requeue eligibility.
    # @return [Boolean] true if messages with the given status can be requeued, false otherwise.
    def can_requeue_all?(status:)
      REQUEUE_STATUSES.include?(status&.to_sym)
    end

    # Requeues all messages with a specific status in batches.
    # @param status [Symbol] the status of messages to requeue.
    # @param batch_size [Integer] number of messages to requeue in each batch.
    # @param time [Time] current time context used to update timestamps.
    # @param publisher_id [Integer, nil] the ID of the publisher.
    # @param publisher_name [String, nil] the name of the publisher.
    # @return [Hash] the count of messages that were requeued.
    def requeue_all(status:, batch_size: 100, time: ::Time,
                    publisher_id: nil, publisher_name: nil)
      if !can_requeue_all?(status: status)
        status_formatted = status.nil? ? "nil" : status

        raise ArgumentError,
          "Status #{status_formatted} must be one of #{REQUEUE_STATUSES.join(", ")}"
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
              .lock("FOR UPDATE SKIP LOCKED")
              .pluck(:id)

            current_utc_time = time.now.utc

            requeued_count_batch = Models::Message
              .where(id: locked_ids)
              .update_all(
                status: Message::Status::QUEUED,
                updated_at: current_utc_time,
                queued_at: current_utc_time,
                buffered_at: nil,
                publishing_at: nil,
                published_at: nil,
                failed_at: nil,
                publisher_id: publisher_id,
                publisher_name: publisher_name)

            requeued_count += requeued_count_batch
          end
        end

        break if requeued_count_batch < batch_size
      end

      { requeued_count: requeued_count }
    end

    # Requeues a specific set of messages by their IDs.
    # @param ids [Array<Integer>] the IDs of messages to requeue.
    # @param publisher_id [Integer, nil] the ID of the publisher.
    # @param publisher_name [String, nil] the name of the publisher.
    # @param time [Time] current time context used to update timestamps.
    # @return [Hash] the count of messages that were requeued and the IDs of those not requeued.
    def requeue_by_ids(ids:, publisher_id: nil, publisher_name: nil, time: Time)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          locked_ids = Models::Message
            .where(id: ids)
            .order(updated_at: :asc)
            .lock("FOR UPDATE SKIP LOCKED")
            .pluck(:id)

          current_utc_time = time.now.utc

          requeued_count = Models::Message
            .where(id: locked_ids)
            .update_all(
              status: Message::Status::QUEUED,
              updated_at: time.now.utc,
              queued_at: current_utc_time, # TODO: confirm this
              buffered_at: nil,
              publishing_at: nil,
              published_at: nil,
              failed_at: nil,
              publisher_id: publisher_id,
              publisher_name: publisher_name)

          { requeued_count: requeued_count, not_requeued_ids: ids - locked_ids }
        end
      end
    end

    # Deletes all messages that match certain criteria in batches.
    # @param status [Symbol, nil] the status of messages to delete.
    # @param batch_size [Integer] the number of messages to delete in each batch.
    # @param older_than [Time, nil] threshold time before which messages are eligible for deletion.
    # @return [Hash] the count of messages that were deleted.
    def delete_all(status: nil, batch_size: 100, older_than: nil)
      deleted_batch_count = delete_batch(
        status: status, batch_size: batch_size, older_than: older_than)[:deleted_count]
      deleted_count = deleted_batch_count

      while deleted_batch_count == batch_size
        deleted_batch_count = delete_batch(
          status: status, batch_size: batch_size, older_than: older_than)[:deleted_count]

        deleted_count += deleted_batch_count
      end

      { deleted_count: deleted_count }
    end

    # Deletes a batch of messages
    # @param status [Symbol, nil] the status of messages to delete.
    # @param batch_size [Integer] the number of messages to delete in each batch.
    # @return [Hash] the count of messages that were deleted.
    def delete_batch(status: nil, batch_size: 100, older_than: nil)
      deleted_count = 0

      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          query = Models::Message.all
          query = query.where(status: status) unless status.nil?
          query = query.where("updated_at < ?", older_than) if older_than

          messages = query.order(:updated_at)
            .limit(batch_size)
            .lock("FOR UPDATE SKIP LOCKED")
            .pluck(:id, :status)
            .map { |message_id, message_status| { id: message_id, status: message_status } }
          message_ids = messages.map { |message| message[:id] }

          Models::Frame.joins(:exception).where(exception: { message_id: message_ids }).delete_all
          Models::Exception.where(message_id: message_ids).delete_all

          deleted_count = Models::Message.where(id: message_ids).delete_all

          [Message::Status::PUBLISHED, Message::Status::FAILED].each do |message_status|
            current_messages = messages.select { |message| message[:status] == message_status }

            if current_messages.any?
              setting_name = "messages.#{message_status}.count.historic"
              setting = Models::Setting.lock("FOR UPDATE").find_by!(name: setting_name)
              setting.update!(value: setting.value.to_i + current_messages.count).to_s
            end
          end
        end
      end

      { deleted_count: deleted_count }
    end

    # Deletes a specific set of messages by their IDs.
    # @param ids [Array<Integer>] the IDs of messages to delete.
    # @return [Hash] the count of messages that were deleted and the IDs of those not deleted.
    def delete_by_ids(ids:)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          messages = Models::Message
            .where(id: ids)
            .lock("FOR UPDATE SKIP LOCKED")
            .pluck(:id, :status)
            .map { |id, status| { id: id, status: status } }

          message_ids = messages.map { |message| message[:id] }

          Models::Frame
            .joins(:exception)
            .where(exception: { message_id: message_ids })
            .delete_all

          Models::Exception.where(message_id: message_ids).delete_all

          deleted_count = Models::Message.where(id: message_ids).delete_all

          [Message::Status::PUBLISHED, Message::Status::FAILED].each do |status|
            current_messages = messages.select { |message| message[:status] == status }

            if current_messages.any?
              setting_name = "messages.#{status}.count.historic"
              setting = Models::Setting.lock("FOR UPDATE").find_by!(name: setting_name)
              setting.update!(value: setting.value.to_i + current_messages.count).to_s
            end
          end

          { deleted_count: deleted_count, not_deleted_ids: ids - message_ids }
        end
      end
    end

    # Retrieves and calculates metrics related to message statuses, including counts and throughput.
    # @param time [Time] current time context used for calculating metrics.
    # @return [Hash] detailed metrics about messages across various statuses.
    def metrics(time: ::Time)
      metrics = { all: { count: { current: 0 } } }

      Models::Message::STATUSES.each do |status|
        metrics[status.to_sym] = { count: { current: 0 }, latency: 0, throughput: 0 }
      end

      grouped_messages = nil

      current_utc_time = time.now.utc

      ActiveRecord::Base.connection_pool.with_connection do
        time_condition = ActiveRecord::Base.sanitize_sql_array([
          "updated_at >= ?", current_utc_time - 1.second
        ])

        grouped_messages = Models::Message
          .group(:status)
          .select(
            "status, COUNT(*) AS count, MIN(updated_at) AS oldest_updated_at",
            "SUM(CASE WHEN #{time_condition} THEN 1 ELSE 0 END) AS throughput")
          .to_a

        metrics[:published][:count][:historic] = Models::Setting
          .find_by!(name: "messages.published.count.historic").value.to_i

        metrics[:failed][:count][:historic] = Models::Setting
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
