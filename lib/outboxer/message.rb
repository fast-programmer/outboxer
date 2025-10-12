module Outboxer
  # Message lifecycle management including queuing and publishing of messages.
  module Message
    module_function

    STATUSES = Models::Message::STATUSES
    Status = Models::Message::Status

    class Error < StandardError; end
    class MissingPartition < Error; end

    PARTITION_COUNT = Integer(ENV.fetch("OUTBOXER_MESSAGE_PARTITION_COUNT", 64))
    PARTITIONS = (0...PARTITION_COUNT)

    # Seed partitions.
    #
    # This method is idempotent and can be safely re-run.
    #
    # @param logger [#info, #error, #fatal, nil] optional logger
    # @param time [Time] time source for created_at / updated_at.
    # @return [Integer] number of rows ensured per table.
    def seed_partitions(logger: nil, time: ::Time)
      current_utc_time = time.now.utc

      [Models::MessageCount, Models::MessageTotal].each do |model|
        PARTITIONS.each do |partition|
          STATUSES.each do |status|
            model.create_or_find_by!(status: status, partition: partition) do |record|
              record.value      = 0
              record.created_at = current_utc_time
              record.updated_at = current_utc_time
            end
          end
        end
      end

      logger&.info "Seeded #{PARTITIONS.size} partitions"

      nil
    end

    # Calculates the partition number for a given message ID.
    #
    # @param id [Integer] the unique message ID used to determine the partition.
    # @param partition_count [Integer] the total number of partitions to divide messages across.
    #   Defaults to PARTITION_COUNT.
    # @return [Integer] the partition number derived by taking the ID modulo partition_count.
    #
    # @example
    #   calculate_partition(id: 12345)
    #   # => 17
    def calculate_partition(id:, partition_count: PARTITION_COUNT)
      id % partition_count
    end

    # Queues a new message.
    #
    # @overload queue(messageable:, attempt: 1, logger: nil, time: ::Time)
    #   @param messageable [Object] the associated object; must respond to `id` and `class.name`.
    #   @param attempt [Integer] call attempt counter; first call should leave as default (1).
    #   @param logger [#info, #error, #fatal, nil] optional logger
    #   @param time [Time] time context for setting timestamps.
    #
    # @overload queue(messageable_type:, messageable_id:, attempt: 1, logger: nil, time: ::Time)
    #   @param messageable_type [String] the associated object type name.
    #   @param messageable_id [Integer, String] the associated object identifier.
    #   @param attempt [Integer] call attempt counter; first call should leave as default (1).
    #   @param logger [#info, #error, #fatal, nil] optional logger
    #   @param time [Time] time context for setting timestamps.
    #
    # @return [Hash] a serialized message hash with keys:
    #   - `:id` [Integer]
    #   - `:status` [String]
    #   - `:messageable_type` [String]
    #   - `:messageable_id` [Integer, String]
    #   - `:updated_at` [Time]
    # @raise [Outboxer::Message::MissingPartition] when partition seed absent and `attempt` > 1.
    # @raise [Outboxer::Message::Error] on other failures during queuing.
    # @example Using an object
    #   Outboxer::Message.queue(messageable: event)
    # @example Using explicit type and id
    #   Outboxer::Message.queue(messageable_type: "Event", messageable_id: 42)
    def queue(messageable: nil, messageable_type: nil, messageable_id: nil,
              attempt: 1, logger: nil, time: ::Time)
      current_utc_time = time.now.utc

      type, id =
        if messageable
          [messageable.class.name, messageable.id]
        elsif messageable_type && messageable_id
          [String(messageable_type), messageable_id]
        else
          raise ArgumentError,
            "Provide either messageable or messageable_type and messageable_id"
        end

      ActiveRecord::Base.transaction do
        message = Models::Message.create!(
          status: Status::QUEUED,
          messageable_id: id,
          messageable_type: type,
          queued_at: current_utc_time,
          updated_at: current_utc_time
        )

        partition = calculate_partition(id: message.id)

        updated_count = Models::MessageCount
          .where(status: Status::QUEUED, partition: partition)
          .update_all(["value = value + ?, updated_at = ?", 1, current_utc_time])

        updated_total = Models::MessageTotal
          .where(status: Status::QUEUED, partition: partition)
          .update_all(["value = value + ?, updated_at = ?", 1, current_utc_time])

        if updated_count.zero? || updated_total.zero?
          raise MissingPartition, "Missing partition"
        end

        {
          id: message.id,
          lock_version: message.lock_version,
          status: message.status,
          messageable_type: message.messageable_type,
          messageable_id: message.messageable_id,
          updated_at: message.updated_at
        }
      end
    rescue MissingPartition
      if attempt == 1
        Message.seed_partitions(time: time, logger: logger)

        Message.queue(
          messageable: messageable,
          messageable_type: messageable_type,
          messageable_id: messageable_id,
          attempt: attempt + 1,
          logger: logger,
          time: time
        )
      else
        raise
      end
    end

    # Publishes the next queued message.
    #
    # Behavior depends on whether a block is given:
    #
    # - With a block:
    #     Transitions the next message from **queued** → **publishing**, yields it for processing,
    #     then marks it **published** on success or **failed** on error.
    #     Logs informational, error, or fatal output if a logger is provided.
    #     Rescues `StandardError` (marks failed, logs error) and continues.
    #     Rescues `Exception` (marks failed, logs fatal) and re-raises.
    #
    # - Without a block:
    #     Transitions the next message from **queued** → **publishing** and returns it immediately.
    #     No further publishing or failure handling is performed.
    #
    # In both cases, returns `nil` if no queued message exists.
    #
    # @param logger [#info, #error, #fatal, nil] optional logger for lifecycle logging
    # @param time [Time, #now] a time source; must respond to `now`
    #
    # @overload publish(logger: nil, time: ::Time)
    #   Moves one message from **queued** to **publishing** without processing.
    #   @return [Hash, nil] the message hash with:
    #     - `:id` [Integer]
    #     - `:messageable_type` [String]
    #     - `:messageable_id` [Integer, String]
    #     or `nil` if no queued message exists.
    #   @example Transition without processing
    #     message = Outboxer::Message.publish
    #     if message
    #       # The message is now marked as publishing
    #     end
    #
    # @overload publish(logger: nil, time: ::Time) { |message| ... }
    #   Publishes one message with full success and failure handling.
    #   @yield [message] the message selected for publishing
    #   @yieldparam message [Hash] the message data with:
    #     - `:id` [Integer]
    #     - `:messageable_type` [String]
    #     - `:messageable_id` [Integer, String]
    #   @yieldreturn [Object] result of the block (ignored)
    #   @return [Hash, nil] the same yielded message hash, or `nil` if no queued message exists
    #   @raise [Exception] re-raises non-StandardError exceptions after marking failed
    #   @example Publish with processing
    #     Outboxer::Message.publish(logger: logger) do |message|
    #       # Publish message to a broker here
    #     end
    def publish(logger: nil, time: ::Time)
      publishing_started_at = time.now.utc
      message = Message.publishing(time: time)
      return if message.nil?

      logger&.info(
        "Outboxer message publishing id=#{message[:id]} " \
          "messageable_type=#{message[:messageable_type]} " \
          "messageable_id=#{message[:messageable_id]}")

      if block_given?
        begin
          yield message
        rescue StandardError => error
          publishing_failed(id: message[:id], error: error, time: time)

          logger&.error(
            "Outboxer message publishing failed id=#{message[:id]} " \
              "duration_ms=#{((time.now.utc - publishing_started_at) * 1000).to_i}\n" \
              "#{error.class}: #{error.message}\n" \
              "#{error.backtrace.join("\n")}")
        rescue Exception => error
          publishing_failed(id: message[:id], error: error, time: time)

          logger&.fatal(
            "Outboxer message publishing failed id=#{message[:id]} " \
              "duration_ms=#{((time.now.utc - publishing_started_at) * 1000).to_i}\n" \
              "#{error.class}: #{error.message}\n" \
              "#{error.backtrace.join("\n")}")

          raise
        else
          published(id: message[:id], time: time)

          logger&.info(
            "Outboxer message published id=#{message[:id]} " \
              "duration_ms=#{((time.now.utc - publishing_started_at) * 1000).to_i}")
        end
      end

      message
    end

    # Selects and locks the next available message in **queued** status
    # and transitions it to **publishing**.
    #
    # Uses `FOR UPDATE SKIP LOCKED` to safely publish one message from the queue
    # across concurrent processes. Updates `publishing_at` and `updated_at`
    # to the current UTC time before returning.
    #
    # @param time [Time, #now] a time source; must respond to `now`
    # @return [Hash, nil] a hash with:
    #   - `:id` [Integer]
    #   - `:messageable_type` [String]
    #   - `:messageable_id` [Integer, String]
    #   or `nil` if no queued message was available
    # @note Runs inside a database transaction and uses the ActiveRecord connection pool.
    # @example
    #   message = Outboxer::Message.publishing(time: Time)
    def publishing(time: ::Time)
      current_utc_time = time.now.utc

      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          message = Models::Message
            .select(:id, :messageable_type, :messageable_id)
            .where(status: Status::QUEUED)
            .order(:id)
            .limit(1)
            .lock("FOR UPDATE SKIP LOCKED")
            .first

          if message.nil?
            nil
          else
            message.update!(
              status: Status::PUBLISHING,
              updated_at: current_utc_time,
              publishing_at: current_utc_time)

            partition = calculate_partition(id: message.id)

            Models::MessageCount
              .where(status: Status::QUEUED, partition: partition)
              .update_all(["value = value - ?, updated_at = ?", 1, current_utc_time])

            Models::MessageCount
              .where(status: Status::PUBLISHING, partition: partition)
              .update_all(["value = value + ?, updated_at = ?", 1, current_utc_time])

            Models::MessageTotal
              .where(status: Status::PUBLISHING, partition: partition)
              .update_all(["value = value + ?, updated_at = ?", 1, current_utc_time])

            {
              id: message.id,
              lock_version: message.lock_version,
              messageable_type: message.messageable_type,
              messageable_id: message.messageable_id
            }
          end
        end
      end
    end

    # Marks a message in **publishing** status as **published**.
    #
    # Ensures that the message is currently in the **publishing** state
    # before transitioning. Updates `published_at` and `updated_at`
    # to the current UTC time.
    #
    # @param id [Integer] the ID of the message to mark as published
    # @param time [Time, #now] a time source; must respond to `now`
    # @return [nil]
    # @raise [Outboxer::Message::Error] if the message is not in publishing state
    # @note Executes within a transaction using a `SELECT ... FOR UPDATE` lock.
    # @example
    #   Outboxer::Message.published(id: message[:id], time: Time)
    def published(id:, time: ::Time)
      current_utc_time = time.now.utc

      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          message = Models::Message.includes(exceptions: :frames).lock.find_by!(id: id)

          if message.status != Models::Message::Status::PUBLISHING
            raise Error, "Status must be publishing"
          end

          message.exceptions.each { |exception| exception.frames.each(&:delete) }
          message.exceptions.delete_all
          message.delete

          partition = calculate_partition(id: message.id)

          Models::MessageCount
            .where(status: Status::PUBLISHING, partition: partition)
            .update_all(["value = value - ?, updated_at = ?", 1, current_utc_time])

          Models::MessageCount
            .where(status: Status::PUBLISHED, partition: partition)
            .update_all(["value = value + ?, updated_at = ?", 1, current_utc_time])

          Models::MessageTotal
            .where(status: Status::PUBLISHED, partition: partition)
            .update_all(["value = value + ?, updated_at = ?", 1, current_utc_time])

          nil
        end
      end
    end

    # Marks a message in **publishing** status as **failed** and records the exception details.
    #
    # Sets `failed_at` and `updated_at` to the current UTC time,
    # persists the error’s class, message, and backtrace (if present).
    # Ensures the message is currently in **publishing** state before updating.
    #
    # @param id [Integer] the ID of the message to mark as failed
    # @param error [Exception, nil] optional error to persist (class name, message text, backtrace)
    # @param time [Time, #now] a time source; must respond to `now`
    # @return [nil]
    # @raise [Outboxer::Message::Error] if the message is not in publishing state
    # @note Runs inside a transaction and uses `SELECT ... FOR UPDATE` locking.
    # @example
    #   Outboxer::Message.publishing_failed(id: message[:id], time: Time)
    def publishing_failed(id:, error: nil, time: ::Time)
      current_utc_time = time.now.utc

      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          message = Models::Message.lock.find_by!(id: id)

          if message.status != Models::Message::Status::PUBLISHING
            raise Error, "Status must be publishing"
          end

          message.update!(
            status: Status::FAILED,
            updated_at: current_utc_time, failed_at: current_utc_time)

          if error
            exception = message.exceptions.create!(
              class_name: error.class.name, message_text: error.message)

            Array(error.backtrace).each_with_index do |backtrace_line, index|
              exception.frames.create!(index: index, text: backtrace_line)
            end
          end

          partition = calculate_partition(id: message.id)

          Models::MessageCount
            .where(status: Status::PUBLISHING, partition: partition)
            .update_all(["value = value - ?, updated_at = ?", 1, current_utc_time])

          Models::MessageCount
            .where(status: Status::FAILED, partition: partition)
            .update_all(["value = value + ?, updated_at = ?", 1, current_utc_time])

          Models::MessageTotal
            .where(status: Status::FAILED, partition: partition)
            .update_all(["value = value + ?, updated_at = ?", 1, current_utc_time])

          {
            lock_version: message.lock_version
          }
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
    # @param publishing_at [Time, nil] optional timestamp when message was marked publishing.
    # @param published_at [Time, nil] optional timestamp when message was marked published.
    # @param failed_at [Time, nil] optional timestamp when message was marked failed.
    # @param publisher_id [Integer, nil] optional publisher ID.
    # @param publisher_name [String, nil] optional publisher name.
    # @return [Hash] serialized message details.
    def serialize(id:, status:, messageable_type:, messageable_id:, updated_at:,
                  queued_at: nil, publishing_at: nil, published_at: nil, failed_at: nil,
                  publisher_id: nil, publisher_name: nil)
      {
        id: id,
        status: status,
        messageable_type: messageable_type,
        messageable_id: messageable_id,
        updated_at: updated_at,
        queued_at: queued_at,
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

    # Iterates or returns an enumerator of message ids filtered by status and time.
    #
    # @param status [Symbol, nil] optional filter for message status; nil = all
    # @param older_than [Time, nil] optional cutoff; only messages updated before this time
    # @param batch_size [Integer] number of records to process per batch (default: 1000)
    # @yield [id] yields each message id if a block is given
    # @return [Enumerator<Integer>] enumerator of ids if no block given
    #
    # @example
    #   # Delete all failed messages
    #   Outboxer::Message.each_id(status: :failed, older_than: Time.now.utc) do |id|
    #     Outboxer::Message.delete(id: id, time: Time)
    #   end
    def each_id(status: nil, older_than: nil, batch_size: 1_000, &block)
      scope = Models::Message.all
      scope = scope.where(status: status) unless status.nil?
      scope = scope.where("updated_at < ?", older_than) if older_than

      enumerator = Enumerator.new do |yielder|
        scope.select(:id).in_batches(of: batch_size) do |relation|
          relation.pluck(:id).each { |id| yielder << id }
        end
      end

      return enumerator unless block_given?

      enumerator.each(&block)

      nil
    end

    # Deletes a message by ID.
    # @param id [Integer] the ID of the message to delete.
    # @return [Hash] details of the deleted message.
    def delete(id:, time: ::Time)
      current_utc_time = time.now.utc

      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          message = Models::Message.includes(exceptions: :frames).lock.find_by!(id: id)

          message.exceptions.each { |exception| exception.frames.each(&:delete) }
          message.exceptions.delete_all
          message.delete

          partition = calculate_partition(id: message.id)

          Models::MessageCount
            .where(status: message.status, partition: partition)
            .update_all(["value = value - ?, updated_at = ?", 1, current_utc_time])

          { id: id }
        end
      end
    end

    REQUEUE_STATUSES = [:publishing, :failed]

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
      current_utc_time = time.now.utc

      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          message = Models::Message.lock.find_by!(id: id)

          partition = calculate_partition(id: message.id)

          Models::MessageCount
            .where(status: message.status, partition: partition)
            .update_all(["value = value - ?, updated_at = ?", 1, current_utc_time])

          message.update!(
            status: Message::Status::QUEUED,
            updated_at: current_utc_time,
            queued_at: current_utc_time,
            publishing_at: nil,
            published_at: nil,
            failed_at: nil,
            publisher_id: publisher_id,
            publisher_name: publisher_name)

          Models::MessageCount
            .where(status: Status::QUEUED, partition: partition)
            .update_all(["value = value + ?, updated_at = ?", 1, current_utc_time])

          Models::MessageTotal
            .where(status: Status::QUEUED, partition: partition)
            .update_all(["value = value + ?, updated_at = ?", 1, current_utc_time])

          { id: id }
        end
      end
    end

    LIST_STATUS_OPTIONS = [nil, :queued, :publishing, :failed]
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

    # Retrieves and calculates metrics related to message statuses, including counts and totals.
    # Latency and throughput are placeholders (0) until partitioned metrics tables are implemented.
    # @return [Hash] detailed metrics across various message statuses.
    def metrics
      metrics = { all: { count: { current: 0 } } }

      Models::Message::STATUSES.each do |status|
        metrics[status.to_sym] = {
          count: { current: 0 },
          latency: 0,
          throughput: 0
        }
      end

      counts_by_status = count_by_status
      totals_by_status = total_by_status

      Models::Message::STATUSES.each do |status|
        status_key = status.to_s
        status_symbol = status.to_sym

        current_count = counts_by_status[status_key]
        metrics[status_symbol][:count][:current] = current_count
        metrics[status_symbol][:count][:total] = totals_by_status[status_key]
        metrics[:all][:count][:current] += current_count

        metrics[status_symbol][:latency] = 0
        metrics[status_symbol][:throughput] = 0
      end

      metrics[:published][:count][:total] = totals_by_status["published"].to_i
      metrics[:failed][:count][:total] = totals_by_status["failed"].to_i

      metrics
    end

    # Returns the current counts per status aggregated across all partitions.
    #
    # @return [Hash{String=>Integer}] map of status name (string) to current count.
    # @example
    #   Outboxer::Message.count_by_status
    #   # => { "queued" => 123, "publishing" => 4, "published" => 987, "failed" => 2 }
    def count_by_status
      Message::STATUSES
        .index_with { 0 }
        .merge(Models::MessageCount.group(:status).sum(:value).transform_keys(&:to_s))
    end

    # Returns the total (lifetime) counts per status aggregated across all partitions.
    #
    # @return [Hash{String=>Integer}] map of status name (string) to total count.
    # @example
    #   Outboxer::Message.total_by_status
    #   # => { "queued" => 1200, "publishing" => 400, "published" => 100_000, "failed" => 250 }
    def total_by_status
      Message::STATUSES
        .index_with { 0 }
        .merge(Models::MessageTotal.group(:status).sum(:value).transform_keys(&:to_s))
    end
  end
end
