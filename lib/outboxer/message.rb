module Outboxer
  module Message
    extend self

    def backlog(messageable_type:, messageable_id:)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          message = Models::Message.create!(
            messageable_id: messageable_id,
            messageable_type: messageable_type,
            status: Models::Message::Status::BACKLOGGED)

          { id: message.id }
        end
      end
    end

    def find_by_id(id:)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          message = Models::Message.includes(exceptions: :frames).find_by!(id: id)

          {
            id: message.id,
            status: message.status,
            messageable_type: message.messageable_type,
            messageable_id: message.messageable_id,
            created_at: message.created_at.utc.to_s,
            updated_at: message.updated_at.utc.to_s,
            exceptions: message.exceptions.map do |exception|
              {
                id: exception.id,
                class_name: exception.class_name,
                message_text: exception.message_text,
                created_at: exception.created_at.utc.to_s,
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
    rescue ActiveRecord::RecordNotFound
      raise NotFound, "Couldn't find Outboxer::Models::Message with id #{id}"
    end

    def publishing(id:)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          message = Models::Message.lock.find_by!(id: id)

          if message.status != Models::Message::Status::QUEUED
            raise InvalidTransition,
              "cannot transition outboxer message #{message.id} " \
              "from #{message.status} to #{Models::Message::Status::PUBLISHING}"
          end

          message.update!(status: Models::Message::Status::PUBLISHING)

          {
            id: id,
            status: message.status,
            messageable_type: message.messageable_type,
            messageable_id: message.messageable_id
          }
        end
      end
    end


    def published(id:)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          message = Models::Message.lock.find_by!(id: id)

          if message.status != Models::Message::Status::PUBLISHING
            raise InvalidTransition,
              "cannot transition outboxer message #{message.id} " \
              "from #{message.status} to (deleted)"
          end

          message.exceptions.each { |exception| exception.frames.each(&:delete) }
          message.exceptions.delete_all
          message.delete

          { id: id }
        end
      end
    end

    def failed(id:, exception:)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          message = Models::Message.order(created_at: :asc).lock.find_by!(id: id)

          if message.status != Models::Message::Status::PUBLISHING
            raise InvalidTransition,
              "cannot transition outboxer message #{id} " \
              "from #{message.status} to #{Models::Message::Status::FAILED}"
          end

          message.update!(status: Models::Message::Status::FAILED)

          outboxer_exception = message.exceptions.create!(
            class_name: exception.class.name, message_text: exception.message)

          exception.backtrace.each_with_index do |frame, index|
            outboxer_exception.frames.create!(index: index, text: frame)
          end

          { id: id }
        end
      end
    end

    def delete(id:)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          message = Models::Message.includes(exceptions: :frames).lock.find_by!(id: id)

          message.exceptions.each { |exception| exception.frames.each(&:delete) }
          message.exceptions.delete_all
          message.delete

          { id: id }
        end
      end
    end

    def republish(id:)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          message = Models::Message.lock.find_by!(id: id)

          if message.status != Models::Message::Status::FAILED
            raise InvalidTransition,
              "cannot transition outboxer message #{id} " \
              "from #{message.status} to #{Models::Message::Status::BACKLOGGED}"
          end

          message.update!(status: Models::Message::Status::BACKLOGGED)

          { id: id }
        end
      end
    end

    def stop_publishing
      @publishing = false
    end

    def publish(threads: 5, queue: 10, poll: 1,
                logger: Logger.new($stdout, level: Logger::INFO),
                kernel: Kernel, &block)
      logger.formatter = proc do |severity, datetime, progname, msg|
        "#{msg}\n"
      end

      logger.info  "              _   _                        "
      logger.info  "             | | | |                       "
      logger.info  "   ___  _   _| |_| |__   _____  _____ _ __ "
      logger.info  "  / _ \\| | | | __| '_ \\ / _ \\ \\/ / _ \\ '__|"
      logger.info  " | (_) | |_| | |_| |_) | (_) >  <  __/ |   "
      logger.info  "  \\___/ \\__,_|\\__|_.__/ \\___/_/\\_\\___|_|   "
      logger.info  "                                           "
      logger.info  "                                           "

      logger.info "#{Time.now.strftime('%Y-%m-%dT%H:%M:%S.%LZ')} pid=#{Process.pid} " \
        "tid=#{Thread.current.object_id} INFO: Running in ruby #{RUBY_VERSION} " \
        "(#{RUBY_RELEASE_DATE} revision #{RUBY_REVISION[0, 10]}) [#{RUBY_PLATFORM}]"

      unless Database.connected?
        logger.info "#{Time.now.strftime('%Y-%m-%dT%H:%M:%S.%LZ')} pid=#{Process.pid} " \
          "tid=#{Thread.current.object_id} INFO: Connecting to database"

        Database.connect(config: Database.config) unless Database.connected?

        logger.info "#{Time.now.strftime('%Y-%m-%dT%H:%M:%S.%LZ')} pid=#{Process.pid} " \
          "tid=#{Thread.current.object_id} INFO: Connected to database"
      end

      ruby_queue = Queue.new

      pid = Process.pid

      logger.info "#{Time.now.strftime('%Y-%m-%dT%H:%M:%S.%LZ')} pid=#{Process.pid} " \
        "tid=#{Thread.current.object_id} INFO: Initializing #{threads} worker threads"

      ruby_threads = threads.times.map do
        Thread.new do
          tid = Thread.current.object_id.to_s(36)

          loop do
            begin
              message = ruby_queue.pop
              break if message.nil?

              start_time = message[:start_time]

              message = Message.publishing(id: message[:id])
              logger.info "#{Time.now.strftime('%Y-%m-%dT%H:%M:%S.%LZ')} pid=#{pid} tid=#{tid} INFO: Publishing message #{message[:id]} for #{message[:messageable_type]}::#{message[:messageable_id]} in #{(Time.now.utc - start_time).round(3)}s"

              begin
                block.call(message)
              rescue Exception => exception
                Message.failed(id: message[:id], exception: exception)
                logger.info "#{Time.now.strftime('%Y-%m-%dT%H:%M:%S.%LZ')} pid=#{pid} tid=#{tid} INFO: Failed to publish message #{message[:id]} for #{message[:messageable_type]}::#{message[:messageable_id]} in #{(Time.now.utc - start_time).round(3)}s"

                raise
              end

              Message.published(id: message[:id])
              logger.info "#{Time.now.strftime('%Y-%m-%dT%H:%M:%S.%LZ')} pid=#{pid} tid=#{tid} INFO: Published message #{message[:id]} for #{message[:messageable_type]}::#{message[:messageable_id]} in #{(Time.now.utc - start_time).round(3)}s"
            rescue => exception
              logger.error "#{Time.now.strftime('%Y-%m-%dT%H:%M:%S.%LZ')} pid=#{pid} tid=#{tid} ERROR: #{exception.class}: #{exception.message} in #{(Time.now.utc - start_time).round(3)}s"
              exception.backtrace.each { |line| logger.error line }
            rescue Exception => exception
              logger.fatal "#{Time.now.strftime('%Y-%m-%dT%H:%M:%S.%LZ')} pid=#{pid} tid=#{tid} FATAL: #{exception.class}: #{exception.message} in #{(Time.now.utc - start_time).round(3)}s"
              exception.backtrace.each { |line| logger.error line }

              @publishing = false

              break
            end
          end
        end
      end

      logger.info "#{Time.now.strftime('%Y-%m-%dT%H:%M:%S.%LZ')} pid=#{Process.pid} " \
        "tid=#{Thread.current.object_id} INFO: Initialized #{threads} worker threads"

      @publishing = true

      logger.info "#{Time.now.strftime('%Y-%m-%dT%H:%M:%S.%LZ')} pid=#{Process.pid} " \
        "tid=#{Thread.current.object_id} INFO: Queuing up to #{queue} messages every #{poll}s"

      while @publishing
        begin
          messages = []

          queue_available = queue - ruby_queue.length
          queue_stats = { total: queue, current: ruby_queue.length, available: queue_available }
          logger.debug "Queue Stats: #{queue_stats}"

          logger.debug "Pool Stats: #{ActiveRecord::Base.connection_pool.stat}"

          messages = (queue_available > 0) ? Messages.queue(limit: queue_available) : []
          logger.debug "Fetched #{messages.length} backlogged messages for queuing."

          messages.each do |message|
            logger.info "#{Time.now.strftime('%Y-%m-%dT%H:%M:%S.%LZ')} pid=#{pid} tid=#{Thread.current.object_id.to_s(36)} INFO: Queuing message #{message[:id]} for #{message[:messageable_type]}::#{message[:messageable_id]} "
            ruby_queue.push({ id: message[:id], start_time: Time.now.utc })
          end

          logger.debug "Pushed #{messages.length} backlogged messages to queue."

          if messages.empty?
            logger.debug "No new backlogged messages fetched. Sleeping for #{poll} seconds..."

            kernel.sleep(poll)
          elsif ruby_queue.length >= queue
            logger.debug "Queue is full. Sleeping for #{poll} seconds..."

            kernel.sleep(poll)
          else
            logger.debug "Continuing to queue messages."
          end
        rescue => exception
          logger.error "#{exception.class}: #{exception.message}"
        rescue Exception => exception
          logger.fatal "#{exception.class}: #{exception.message}"
          logger.fatal "An unexpected error occurred, stopping the publishing process."

          @publishing = false
        end
      end

      logger.info "#{Time.now.strftime('%Y-%m-%dT%H:%M:%S.%LZ')} pid=#{Process.pid} " \
        "tid=#{Thread.current.object_id} INFO: Shutting down" \

      logger.info "#{Time.now.strftime('%Y-%m-%dT%H:%M:%S.%LZ')} pid=#{Process.pid} " \
        "tid=#{Thread.current.object_id} INFO: Terminating #{threads} worker threads" \

      ruby_threads.length.times { ruby_queue.push(nil) }
      ruby_threads.each(&:join)

      logger.info "#{Time.now.strftime('%Y-%m-%dT%H:%M:%S.%LZ')} pid=#{Process.pid} " \
        "tid=#{Thread.current.object_id} INFO: Terminated #{threads} worker threads" \

      logger.info "#{Time.now.strftime('%Y-%m-%dT%H:%M:%S.%LZ')} pid=#{Process.pid} " \
        "tid=#{Thread.current.object_id} INFO: Disconnecting from database" \

      Database.disconnect

      logger.info "#{Time.now.strftime('%Y-%m-%dT%H:%M:%S.%LZ')} pid=#{Process.pid} " \
        "tid=#{Thread.current.object_id} INFO: Disconnected from database" \

      logger.info "#{Time.now.strftime('%Y-%m-%dT%H:%M:%S.%LZ')} pid=#{Process.pid} " \
        "tid=#{Thread.current.object_id} INFO: Shut down"
    end
  end
end
