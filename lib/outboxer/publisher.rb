module Outboxer
  module Publisher
    extend self

    def connect!(db_config:, logger:)
      ActiveRecord::Base.establish_connection(db_config)

      @logger = ActiveRecord::Base.logger = logger
    end

    def stop!
      @running = false
    end

    def pop_messages_async!(&block)
      @concurrency.times { @threads << pop_message_async!(&block) }
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

        limit = @concurrency - @queue.length
        @logger.debug "concurrency: #{@concurrency}, queue.length: #{@queue.length}"
        messages = (limit > 0) ? Outboxer::Message.unpublished!(limit: limit) : []
        messages.each { |message| @queue.push(message) }

        @logger.debug "Pushed #{messages.length} messages to the queue" unless messages.empty?

        sleep(@poll) if @running && (@queue.empty? || @queue.length >= @concurrency)
      end

      @threads.length.times { @queue.push(nil) }

      @threads.each(&:join)
    end

    def publish!(concurrency:, poll: 1, &block)
      @concurrency = concurrency
      @poll = poll

      @queue = Queue.new
      @threads = []

      @running = false

      pop_messages_async!(&block)

      push_messages!
    end
  end
end
