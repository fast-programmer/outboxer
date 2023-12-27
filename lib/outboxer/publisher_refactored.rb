module Outboxer
  class Publisher
    def initialize(concurrency: 5, poll: 1, logger: Logger.new(STDOUT))
      @concurrency = concurrency
      @poll = poll
      @logger = logger

      @queue = Queue.new
      @threads = []

      @running = false

      @mutex = Mutex.new
    end

    def stop!
      @running = false
    end

    def pop_messages_async!(&block)
      @concurrency.times do
        @threads << Thread.new do
          loop do
            outboxer_message = @queue.pop
            break if outboxer_message.nil?

            begin
              block.call(outboxer_message)
            rescue => exception
              Message.failed!(id: outboxer_message.id, exception: exception)

              raise
            end

            Message.published!(id: outboxer_message.id)
          rescue => exception
            @logger.error "Error: #{exception.class}: #{exception.message}"
          end
        end
      end
    end

    def push_messages!
      @running = true

      while @running
        messages = []

        limit = @concurrency - @queue.length
        messages = (limit > 0) ? Outboxer::Message.unpublished!(limit: limit) : []
        messages.each { |message| @queue.push(message) }

        sleep(@poll) if @running && messages.empty?
      end

      @threads.length.times { queue.push(nil) }

      @threads.each(&:join)
    end

    def publish!(&block)
      pop_messages_async!(&block)

      push_messages!
    end
  end
end
