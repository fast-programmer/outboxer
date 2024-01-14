module Outboxer
  module Publisher
    extend self

    def connect!(db_config:, logger:)
      ActiveRecord::Base.establish_connection(db_config)

      # @logger = ActiveRecord::Base.logger = logger
      @logger = logger
    end

    def stop!
      @running = false
    end

    def pop_messages_async!(&block)
      @threads_max.times { @threads << pop_message_async!(&block) }
    end

    def pop_message_async!(&block)
      Thread.new do
        loop do
          outboxer_message = @queue.pop
          break if outboxer_message.nil?

          @logger.debug "Processing message id: #{outboxer_message.id}"

          begin
            block.call(outboxer_message)
          rescue => exception
            @logger.error "Message processing failed for id: #{outboxer_message.id}, error: #{exception}"

            Message.failed!(id: outboxer_message.id, exception: exception)

            raise
          end

          Message.published!(id: outboxer_message.id)

          @logger.debug "Message processed successfully for id: #{outboxer_message.id}"
        rescue => exception
          @logger.error "Error: #{exception.class}: #{exception.message}"
        rescue Exception => exception
          @logger.fatal "Critical Error: #{exception.class}: #{exception.message}"

          stop!

          break
        end
      end
    end

    def push_messages!
      @running = true

      while @running
        messages = []

        queue_remaining = @queue_max - @queue.length
        messages = (queue_remaining > 0) ? Outboxer::Message.unpublished!(limit: queue_remaining) : []

        if messages.empty?
          log("Sleeping for #{@poll} seconds because there are no messages", messages: messages)
          sleep(@poll)
          log("Slept for #{@poll} seconds", messages: messages)

          next
        end

        log("Pushing #{messages.length} messages to the queue", messages: messages)
        messages.each { |message| @queue.push(message) }
        log("Pushed #{messages.length} messages to the queue", messages: messages)

        if @queue.length >= @queue_max
          log("Sleeping for #{@poll} seconds because queue length >= queue max", messages: messages)
          sleep(@poll)
          log("slept for #{@poll} seconds", messages: messages)
        end
      end

      @threads.length.times { @queue.push(nil) }

      @threads.each(&:join)
    end

    def publish!(threads_max:, queue_max:, poll:, &block)
      @threads_max = threads_max
      @queue_max = queue_max
      @poll = poll

      @queue = Queue.new
      @threads = []

      @running = false

      pop_messages_async!(&block)

      push_messages!
    end

    def log(message, messages:)
      summary = {
        threads_max: @threads_max,
        messages_length: messages.length,
        queue_length: @queue.length
      }

      @logger.debug "#{message} #{summary.to_json}"
    end
  end
end
