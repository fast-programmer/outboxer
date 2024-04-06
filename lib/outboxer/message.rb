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
      Database.connect(config: Database.config) unless Database.connected?

      ruby_queue = Queue.new

      @publishing = true

      main_thread_id = SecureRandom.hex(3)

      logger.info "[TID-#{main_thread_id}] Creating #{threads} worker threads"

      ruby_threads = threads.times.map do
        Thread.new do
          thread_id = SecureRandom.hex(3)

          loop do
            begin
              message = ruby_queue.pop

              if message.nil?
                logger.info "[TID-#{thread_id}] > Shutting down worker thread"

                break
              end

              logger.info "[TID-#{thread_id}] > Publishing message { id: #{message[:id]} } }"
              message = Message.publishing(id: message[:id])

              begin
                block.call(message)
              rescue Exception => exception
                logger.error "[TID-#{thread_id}] > Failed to publish message { id: #{message[:id]}, error: #{exception} }"
                Message.failed(id: message[:id], exception: exception)

                raise
              end

              logger.info "[TID-#{thread_id}] > Published message { id: #{message[:id]} }"
              Message.published(id: message[:id])
            rescue => exception
              logger.error "[TID-#{thread_id}] > #{exception.class}: #{exception.message}"
            rescue Exception => exception
              logger.fatal "[TID-#{thread_id}] > #{exception.class}: #{exception.message}"

              @publishing = false

              break
            end
          end

          logger.info "[TID-#{thread_id}] > Shut down worker thread"
        end
      end

      logger.info "[TID-#{main_thread_id}] Created #{threads} publisher threads"

      logger.info "[TID-#{main_thread_id}] Queuing backlogged messages..."

      while @publishing
        begin
          messages = []

          queue_available = queue - ruby_queue.length
          queue_stats = { total: queue, current: ruby_queue.length, available: queue_available }
          logger.debug "[TID-#{main_thread_id}] Queue Stats: #{queue_stats}"

          logger.debug "[TID-#{main_thread_id}] Pool Stats: #{ActiveRecord::Base.connection_pool.stat}"

          messages = (queue_available > 0) ? Messages.queue(limit: queue_available) : []
          logger.debug "[TID-#{main_thread_id}] Fetched #{messages.length} backlogged messages for queuing."

          messages.each { |message| ruby_queue.push({ id: message[:id] }) }
          logger.debug "[TID-#{main_thread_id}] Pushed #{messages.length} backlogged messages to queue."

          if messages.empty?
            logger.debug "[TID-#{main_thread_id}] No new backlogged messages fetched. Sleeping for #{poll} seconds..."

            kernel.sleep(poll)
          elsif ruby_queue.length >= queue
            logger.debug "[TID-#{main_thread_id}] Queue is full. Sleeping for #{poll} seconds..."

            kernel.sleep(poll)
          else
            logger.debug "[TID-#{main_thread_id}] Continuing to queue messages."
          end
        rescue => exception
          logger.error "[TID-#{main_thread_id}] #{exception.class}: #{exception.message}"
        rescue Exception => exception
          logger.fatal "[TID-#{main_thread_id}] #{exception.class}: #{exception.message}"
          logger.fatal "[TID-#{main_thread_id}] An unexpected error occurred, stopping the publishing process."
          @publishing = false
        end
      end

      logger.info "[TID-#{main_thread_id}] Stopped queueing backlogged messages"

      ruby_threads.length.times { ruby_queue.push(nil) }
      ruby_threads.each(&:join)

      logger.info "[TID-#{main_thread_id}] Stopped publishing queued messages"

      Database.disconnect

      logger.info "[TID-#{main_thread_id}] Shut down gracefully"
    end
  end
end
