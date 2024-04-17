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
      ruby_queue = Queue.new

      @publishing = true

      logger.info "Initializing #{threads} worker threads"
      ruby_threads = threads.times.map do
        Thread.new do
          loop do
            begin
              queued_message = ruby_queue.pop
              break if queued_message.nil?

              queued_at = queued_message[:queued_at]

              message = Message.publishing(id: queued_message[:id])
              logger.info "Publishing message #{message[:id]} for " \
                "#{message[:messageable_type]}::#{message[:messageable_id]} " \
                "in #{(Time.now.utc - queued_at).round(3)}s"

              begin
                block.call(message)
              rescue Exception => exception
                Message.failed(id: message[:id], exception: exception)
                logger.error "Failed to publish message #{message[:id]} for " \
                  "#{message[:messageable_type]}::#{message[:messageable_id]} " \
                  "in #{(Time.now.utc - queued_at).round(3)}s"

                raise
              end

              Message.published(id: message[:id])
              logger.info "Published message #{message[:id]} for " \
                "#{message[:messageable_type]}::#{message[:messageable_id]} " \
                "in #{(Time.now.utc - queued_at).round(3)}s"
            rescue => exception
              logger.error "#{exception.class}: #{exception.message} " \
                "in #{(Time.now.utc - queued_at).round(3)}s"

              exception.backtrace.each { |frame| logger.error frame }
            rescue Exception => exception
              logger.fatal "#{exception.class}: #{exception.message} " \
                "in #{(Time.now.utc - queued_at).round(3)}s"
              exception.backtrace.each { |line| logger.error line }

              @publishing = false

              break
            end
          end
        end
      end
      logger.info "Initialized #{threads} worker threads"

      logger.info "Queuing up to #{queue} messages every #{poll}s"
      while @publishing
        begin
          messages = []

          queue_available = queue - ruby_queue.length
          queue_stats = { total: queue, available: queue_available, current: ruby_queue.length }
          logger.debug "Queue: #{queue_stats}"

          logger.debug "Connection pool: #{ActiveRecord::Base.connection_pool.stat}"

          messages = (queue_available > 0) ? Messages.queue(limit: queue_available) : []
          logger.debug "Updated #{messages.length} messages from backlogged to queued"

          messages.each do |message|
            logger.info "Queuing message #{message[:id]} for " \
              "#{message[:messageable_type]}::#{message[:messageable_id]}"

            ruby_queue.push({ id: message[:id], queued_at: Time.now.utc })
          end

          logger.debug "Pushed #{messages.length} messages to queue."

          if messages.empty?
            logger.debug "Sleeping for #{poll} seconds because no messages were queued..."

            kernel.sleep(poll)
          elsif ruby_queue.length >= queue
            logger.debug "Sleeping for #{poll} seconds because queue was full..."

            kernel.sleep(poll)
          end
        rescue StandardError => exception
          logger.error "#{exception.class}: #{exception.message}"

          kernel.sleep(poll)
        rescue Exception => exception
          logger.fatal "#{exception.class}: #{exception.message}"

          @publishing = false
        end
      end
      logger.info "Stopped queueing messages"

      logger.info "Shutting down #{threads} worker threads"
      ruby_threads.length.times { ruby_queue.push(nil) }
      ruby_threads.each(&:join)
      logger.info "Shut down #{threads} worker threads"
    end
  end
end
