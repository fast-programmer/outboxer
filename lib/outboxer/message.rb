module Outboxer
  # Message lifecycle management including queuing and publishing of messages.
  module Message
    module_function

    STATUSES = Models::Message::STATUSES
    Status = Models::Message::Status

    class Error < StandardError; end

    # Queues a new message.
    #
    # @overload queue(
    #   messageable: nil,
    #   messageable_type: nil,
    #   messageable_id: nil,
    #   hostname: Socket.gethostname,
    #   process_id: Process.pid,
    #   thread_id: Thread.current.object_id,
    #   time: ::Time
    # )
    #   @param messageable [Object, nil] associated object; must respond to `id` and `class.name`.
    #   @param messageable_type [String, nil] the associated object type name.
    #   @param messageable_id [Integer, String, nil] the associated object identifier.
    #   @param hostname [String] name of the host (defaults to `Socket.gethostname`).
    #   @param process_id [Integer] current process ID (defaults to `Process.pid`).
    #   @param thread_id [Integer] current thread ID (defaults to `Thread.current.object_id`).
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
    #
    # @example Using an object
    #   Outboxer::Message.queue(messageable: event)
    #
    # @example Using explicit type and id
    #   Outboxer::Message.queue(messageable_type: "Event", messageable_id: 42)
    #
    # @example Overriding context explicitly
    #   Outboxer::Message.queue(
    #     messageable_type: "Event",
    #     messageable_id: 42,
    #     hostname: "worker1",
    #     process_id: 1234,
    #     thread_id: 5678
    #   )
    def queue(messageable: nil, messageable_type: nil, messageable_id: nil,
              hostname: Socket.gethostname,
              process_id: Process.pid,
              thread_id: Thread.current.object_id,
              time: ::Time)
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

      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          message = Models::Message.create!(
            status: Status::QUEUED,
            messageable_id: id,
            messageable_type: type,
            queued_at: current_utc_time,
            updated_at: current_utc_time
          )

          counter = Models::Message::Counter.lock.find_by(
            hostname: hostname, process_id: process_id, thread_id: thread_id)

          if counter
            counter.update!(
              queued_count: counter.queued_count + 1,
              queued_count_last_updated_at: current_utc_time,
              updated_at: current_utc_time)
          else
            Models::Message::Counter.create!(
              hostname: hostname,
              process_id: process_id,
              thread_id: thread_id,
              queued_count: 1,
              queued_count_last_updated_at: current_utc_time,
              publishing_count: 0,
              published_count: 0,
              failed_count: 0,
              created_at: current_utc_time,
              updated_at: current_utc_time)
          end

          { id: message.id, lock_version: message.lock_version }
        end
      rescue ActiveRecord::RecordNotUnique
        queue(
          messageable: messageable,
          messageable_type: messageable_type,
          messageable_id: messageable_id,
          hostname: hostname,
          process_id: process_id,
          thread_id: thread_id,
          time: time)
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
    def publish(hostname: Socket.gethostname,
                process_id: Process.pid,
                thread_id: Thread.current.object_id,
                logger: nil, time: ::Time)
      publishing_started_at = time.now.utc

      message = Message.publishing(
        hostname: hostname, process_id: process_id, thread_id: thread_id, time: time)

      return if message.nil?

      logger&.info(
        "Outboxer message publishing id=#{message[:id]} " \
          "messageable_type=#{message[:messageable_type]} " \
          "messageable_id=#{message[:messageable_id]}")

      if block_given?
        begin
          yield message
        rescue StandardError => error
          publishing_failed(
            id: message[:id], lock_version: message[:lock_version],
            error: error,
            hostname: hostname, process_id: process_id, thread_id: thread_id,
            time: time)

          logger&.error(
            "Outboxer message publishing failed id=#{message[:id]} " \
              "messageable_type=#{message[:messageable_type]} " \
              "messageable_id=#{message[:messageable_id]} " \
              "duration_ms=#{((time.now.utc - publishing_started_at) * 1000).to_i}\n" \
              "#{error.class}: #{error.message}\n" \
              "#{error.backtrace.join("\n")}")
        rescue Exception => error
          publishing_failed(
            id: message[:id], lock_version: message[:lock_version], error: error,
            hostname: hostname, process_id: process_id, thread_id: thread_id,
            time: time)

          logger&.fatal(
            "Outboxer message publishing failed id=#{message[:id]} " \
              "messageable_type=#{message[:messageable_type]} " \
              "messageable_id=#{message[:messageable_id]} " \
              "duration_ms=#{((time.now.utc - publishing_started_at) * 1000).to_i}\n" \
              "#{error.class}: #{error.message}\n" \
              "#{error.backtrace.join("\n")}")

          raise
        else
          published(id: message[:id], lock_version: message[:lock_version],
            hostname: hostname, process_id: process_id, thread_id: thread_id,
            time: time)

          logger&.info(
            "Outboxer message published id=#{message[:id]} " \
              "messageable_type=#{message[:messageable_type]} " \
              "messageable_id=#{message[:messageable_id]} " \
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
    def publishing(hostname: Socket.gethostname,
                   process_id: Process.pid,
                   thread_id: Thread.current.object_id,
                   time: ::Time)
      current_utc_time = time.now.utc

      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          id, lock_version, messageable_type, messageable_id =
            Models::Message
              .where(status: Status::QUEUED)
              .order(:id)
              .limit(1)
              .lock("FOR UPDATE SKIP LOCKED")
              .pluck(:id, :lock_version, :messageable_type, :messageable_id)
              .first

          if id.nil?
            nil
          else
            Models::Message
              .where(id: id)
              .update_all([
                "lock_version = lock_version + 1, status = ?, updated_at = ?, publishing_at = ?",
                Status::PUBLISHING, current_utc_time, current_utc_time
              ])

            counter_exists = Models::Message::Counter
              .where(hostname: hostname, process_id: process_id, thread_id: thread_id)
              .lock("FOR UPDATE")
              .exists?

            if counter_exists
              Models::Message::Counter
                .where(hostname: hostname, process_id: process_id, thread_id: thread_id)
                .update_all([
                  "queued_count = queued_count - 1, publishing_count = publishing_count + 1, " \
                  "publishing_count_last_updated_at = ?, updated_at = ?",
                  current_utc_time, current_utc_time
                ])
            else
              Models::Message::Counter.insert_all([{
                hostname: hostname,
                process_id: process_id,
                thread_id: thread_id,
                queued_count: -1,
                publishing_count: 1,
                published_count: 0,
                failed_count: 0,
                publishing_count_last_updated_at: current_utc_time,
                created_at: current_utc_time,
                updated_at: current_utc_time
              }])
            end

            {
              id: id,
              lock_version: lock_version + 1,
              messageable_type: messageable_type,
              messageable_id: messageable_id
            }
          end
        end
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordNotFound
        publishing(
          hostname: hostname,
          process_id: process_id,
          thread_id: thread_id,
          time: time
        )
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
    def published(id:, lock_version:,
                  hostname: Socket.gethostname,
                  process_id: Process.pid,
                  thread_id: Thread.current.object_id,
                  time: ::Time)
      current_utc_time = time.now.utc

      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          id, lock_version, status = Models::Message
            .where(id: id)
            .lock("FOR UPDATE")
            .pluck(:id, :lock_version, :status)
            .first

          if status != Models::Message::Status::PUBLISHING
            raise Error, "Status must be publishing"
          end

          exception_ids = Models::Exception.where(message_id: id).pluck(:id)
          Models::Frame.where(exception_id: exception_ids).delete_all
          Models::Exception.where(message_id: id).delete_all
          Models::Message.where(id: id).delete_all

          counter_row = Models::Message::Counter
            .where(hostname: hostname, process_id: process_id, thread_id: thread_id)
            .lock("FOR UPDATE")
            .pluck(:publishing_count, :published_count)
            .first

          if counter_row
            Models::Message::Counter
              .where(hostname: hostname, process_id: process_id, thread_id: thread_id)
              .update_all([
                "publishing_count = publishing_count - 1, " \
                "published_count = published_count + 1, " \
                "published_count_last_updated_at = ?, " \
                "updated_at = ?",
                current_utc_time,
                current_utc_time
              ])
          else
            Models::Message::Counter.insert(
              hostname: hostname,
              process_id: process_id,
              thread_id: thread_id,
              queued_count: 0,
              publishing_count: -1,
              published_count: 1,
              failed_count: 0,
              published_count_last_updated_at: current_utc_time,
              created_at: current_utc_time,
              updated_at: current_utc_time
            )
          end

          { id: id }
        end
      rescue ActiveRecord::RecordNotUnique
        published(
          id: id,
          lock_version: lock_version,
          hostname: hostname,
          process_id: process_id,
          thread_id: thread_id,
          time: time
        )
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
    def publishing_failed(id:, lock_version:, error: nil,
                          hostname: Socket.gethostname,
                          process_id: Process.pid,
                          thread_id: Thread.current.object_id,
                          time: ::Time)
      current_utc_time = time.now.utc

      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          message = Models::Message.lock.find_by!(id: id)

          if message.status != Models::Message::Status::PUBLISHING
            raise Error, "Status must be publishing"
          end

          message.update!(
            lock_version: lock_version,
            status: Status::FAILED,
            updated_at: current_utc_time,
            failed_at: current_utc_time)

          if error
            exception = message.exceptions.create!(
              class_name: error.class.name, message_text: error.message)

            Array(error.backtrace).each_with_index do |backtrace_line, index|
              exception.frames.create!(index: index, text: backtrace_line)
            end
          end

          counter = Models::Message::Counter.lock.find_by(
            hostname: hostname, process_id: process_id, thread_id: thread_id)

          if counter
            counter.update!(
              publishing_count: counter.publishing_count - 1,
              failed_count: counter.failed_count + 1,
              failed_count_last_updated_at: current_utc_time,
              updated_at: current_utc_time)
          else
            Models::Message::Counter.create!(
              hostname: hostname,
              process_id: process_id,
              thread_id: thread_id,
              queued_count: 0,
              publishing_count: 0,
              published_count: 0,
              failed_count: 1,
              failed_count_last_updated_at: current_utc_time,
              created_at: current_utc_time,
              updated_at: current_utc_time)
          end

          {
            id: message.id,
            lock_version: message.lock_version
          }
        end
      rescue ActiveRecord::RecordNotUnique
        publishing_failed(
          id: id,
          lock_version: lock_version,
          error: error,
          hostname: hostname,
          process_id: process_id,
          thread_id: thread_id,
          time: time)
      end
    end

    # Serializes message attributes into a hash.
    #
    # @param id [Integer] message ID.
    # @param lock_version [Integer] message lock_version.
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
    def serialize(id:, lock_version:, status:, messageable_type:, messageable_id:, updated_at:,
                  queued_at: nil, publishing_at: nil, published_at: nil, failed_at: nil,
                  publisher_id: nil, publisher_name: nil)
      {
        id: id,
        lock_version: lock_version,
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
            lock_version: message.lock_version,
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

    # Deletes a message by id.
    # @param id [Integer] the ID of the message to delete.
    # @param lock_version [Integer] message lock_version.
    # @param hostname [String] name of the host (defaults to `Socket.gethostname`).
    # @param process_id [Integer] current process ID (defaults to `Process.pid`).
    # @param thread_id [Integer] current thread ID (defaults to `Thread.current.object_id`).
    # @param time [Time] time context for setting timestamps.
    # @return [Hash] details of the deleted message.
    def delete(id:, lock_version:,
               hostname: Socket.gethostname,
               process_id: Process.pid,
               thread_id: Thread.current.object_id,
               time: ::Time)
      current_utc_time = time.now.utc

      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          message = Models::Message.includes(exceptions: :frames).lock.find_by!(id: id)
          message.update!(lock_version: lock_version, updated_at: current_utc_time)

          message.exceptions.each { |exception| exception.frames.each(&:delete) }
          message.exceptions.delete_all
          message.delete

          counter = Models::Message::Counter.lock.find_by(
            hostname: hostname, process_id: process_id, thread_id: thread_id)

          if counter
            counter.update!(
              queued_count:
                counter.queued_count - (message.status == Status::QUEUED ? 1 : 0),
              publishing_count:
                counter.publishing_count - (message.status == Status::PUBLISHING ? 1 : 0),
              published_count:
                counter.published_count - (message.status == Status::PUBLISHED ? 1 : 0),
              failed_count:
                counter.failed_count - (message.status == Status::FAILED ? 1 : 0),
              updated_at: current_utc_time)
          else
            Models::Message::Counter.create!(
              hostname: hostname,
              process_id: process_id,
              thread_id: thread_id,
              queued_count: 0,
              publishing_count: 0,
              published_count: 0,
              failed_count: 0,
              created_at: current_utc_time,
              updated_at: current_utc_time)
          end

          { id: id }
        end
      rescue ActiveRecord::RecordNotUnique
        delete(
          id: id,
          lock_version: lock_version,
          hostname: hostname,
          process_id: process_id,
          thread_id: thread_id,
          time: time)
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
    def requeue(id:, lock_version:,
                publisher_id: nil, publisher_name: nil,
                hostname: Socket.gethostname,
                process_id: Process.pid,
                thread_id: Thread.current.object_id,
                time: ::Time)
      current_utc_time = time.now.utc

      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          message = Models::Message.lock.find_by!(id: id)
          original_status = message.status

          message.update!(
            lock_version: lock_version,
            status: Message::Status::QUEUED,
            updated_at: current_utc_time,
            queued_at: current_utc_time,
            publishing_at: nil,
            published_at: nil,
            failed_at: nil,
            publisher_id: publisher_id,
            publisher_name: publisher_name)

          counter = Models::Message::Counter.lock.find_by(
            hostname: hostname, process_id: process_id, thread_id: thread_id)

          if counter
            counter.update!(
              queued_count:
                counter.queued_count + 1,
              publishing_count:
                counter.publishing_count - (original_status == Status::PUBLISHING ? 1 : 0),
              published_count:
                counter.published_count - (original_status == Status::PUBLISHED ? 1 : 0),
              failed_count:
                counter.failed_count - (original_status == Status::FAILED ? 1 : 0),
              queued_count_last_updated_at:
                current_utc_time,
              updated_at:
                current_utc_time)
          else
            Models::Message::Counter.create!(
              hostname: hostname,
              process_id: process_id,
              thread_id: thread_id,
              queued_count: 1,
              publishing_count: 0,
              published_count: 0,
              failed_count: 0,
              queued_count_last_updated_at: current_utc_time,
              created_at: current_utc_time,
              updated_at: current_utc_time)
          end

          {
            id: id,
            lock_version: lock_version
          }
        end
      rescue ActiveRecord::RecordNotUnique
        requeue(
          id: id,
          lock_version: lock_version,
          publisher_id: publisher_id,
          publisher_name: publisher_name,
          hostname: hostname,
          process_id: process_id,
          thread_id: thread_id,
          time: time)
      end
    end

    LIST_STATUS_OPTIONS = [nil, :queued, :publishing, :failed]
    LIST_STATUS_DEFAULT = nil

    LIST_SORT_OPTIONS = [:id, :status, :messageable, :queued_at, :updated_at, :publisher_name]
    LIST_SORT_DEFAULT = :updated_at

    LIST_ORDER_OPTIONS = [:asc, :desc]
    LIST_ORDER_DEFAULT = :asc

    LIST_PAGE_DEFAULT = 1

    LIST_PER_PAGE_OPTIONS = [10, 100, 200, 500, 1_000]
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
            lock_version: message.lock_version,
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

    # Rolls up thread_counts into the historic_count,
    # then destroys rolled-up thread_counts.
    #
    # @param time [Time] timestamp context for updated_at
    # @return [Hash] new historic_totals after rollup
    def rollup_counts(time: Time)
      current_utc_time = time.now.utc

      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          # 1. Ensure the historic counter exists (idempotent upsert)
          Models::Message::Counter.increment_counts_by(
            hostname: Models::Message::Counter::HISTORIC_HOSTNAME,
            process_id: Models::Message::Counter::HISTORIC_PROCESS_ID,
            thread_id: Models::Message::Counter::HISTORIC_THREAD_ID,
            current_utc_time: current_utc_time
          )

          # 2. Lock *all* rows (historic counter + thread counters)
          locked_counters = Models::Message::Counter.lock("FOR UPDATE").to_a

          # 3. Identify the historic counter
          historic_counter = locked_counters.find do |r|
            r.hostname == Models::Message::Counter::HISTORIC_HOSTNAME &&
              r.process_id == Models::Message::Counter::HISTORIC_PROCESS_ID &&
              r.thread_id == Models::Message::Counter::HISTORIC_THREAD_ID
          end

          # 4. Everything else is a thread counter
          thread_counters = locked_counters - [historic_counter]

          # 5. Sum all thread counters
          totals = thread_counters.each_with_object(
            queued_count: 0, publishing_count: 0, published_count: 0, failed_count: 0
          ) do |row, sum|
            sum[:queued_count] += row.queued_count
            sum[:publishing_count] += row.publishing_count
            sum[:published_count] += row.published_count
            sum[:failed_count] += row.failed_count
          end

          # 6. Update historic counter
          historic_counter.update!(
            queued_count: historic_counter.queued_count + totals[:queued_count],
            publishing_count: historic_counter.publishing + totals[:publishing_count],
            published_count: historic_counter.published + totals[:published_count],
            failed_count: historic_counter.failed + totals[:failed_count],
            updated_at: current_utc_time
          )

          # 7. Delete all rolled-up rows except historic counter
          Models::Message::Counter.where.not(
            hostname: Models::Message::Counter::HISTORIC_HOSTNAME,
            process_id: Models::Message::Counter::HISTORIC_PROCESS_ID,
            thread_id: Models::Message::Counter::HISTORIC_THREAD_ID
          ).delete_all

          # 8. Return the updated totals
          {
            queued: historic_counter.queued_count,
            publishing: historic_counter.publishing_count,
            published: historic_counter.published_count,
            failed: historic_counter.failed_count
          }
        end
      end
    end

    # Returns the total (lifetime) counts per status aggregated across all threads.
    #
    # @return [Hash{String=>Integer}] map of status name (string) to total count.
    # @example
    #   Message.count_by_status
    #   # => { :queued => 1200, publishing: 400, published: 100_000, failed: 250 }
    def count_by_status
      ActiveRecord::Base.connection_pool.with_connection do
        result = Models::Message::Counter.select(
          "COALESCE(SUM(queued_count), 0)      AS queued",
          "COALESCE(SUM(publishing_count), 0)  AS publishing",
          "COALESCE(SUM(published_count), 0)   AS published",
          "COALESCE(SUM(failed_count), 0)      AS failed",
          "COALESCE(SUM(" \
            "queued_count + publishing_count + " \
            "published_count + failed_count), 0) AS total"
        ).take

        result.attributes.symbolize_keys.slice(
          :queued, :publishing, :published, :failed, :total
        ).transform_values(&:to_i)
      end
    end

    def metrics_by_status(time: Time)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction(isolation: :repeatable_read) do
          counts = Models::Message::Counter.select(
            "COALESCE(SUM(queued_count), 0)      AS queued",
            "COALESCE(SUM(publishing_count), 0)  AS publishing",
            "COALESCE(SUM(published_count), 0)   AS published",
            "COALESCE(SUM(failed_count), 0)      AS failed",
            "COALESCE(SUM(" \
              "queued_count + publishing_count + " \
              "published_count + failed_count), 0) AS total"
          ).take

          min_times = Models::Message.group(:status).minimum(:updated_at)
          min_total = min_times.values.compact.min

          now = time.now.utc
          latencies = min_times.transform_values { |t| t ? (now - t).to_i : 0 }
          latencies["total"] = min_total ? (now - min_total).to_i : 0

          counts_hash = counts.attributes.symbolize_keys.transform_values(&:to_i)

          [:queued, :publishing, :published, :failed, :total].each_with_object({}) do |status, h|
            h[status] = {
              count: counts_hash[status] || 0,
              latency: latencies[status.to_s] || 0
            }
          end
        end
      end
    end
  end
end
