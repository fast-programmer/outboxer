module Outboxer
  module Metrics
    extend self

    def log(statsd:, interval: 60, current_time: Time.current)
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        ActiveRecord::Base.transaction do
          metrics = Models::Metrics.lock('FOR UPDATE NOWAIT').first!

          if metrics.updated_at <= current_time - interval
            oldest_message = Models::Message.where(status: Message::Status::QUEUED).order(updated_at: :asc).first
            queue_latency = oldest_message ? current_time - oldest_message.created_at : 0

            messages_count_by_status = Messages.count_by_status

            statsd.gauge('outboxer.queue.size', messages_count_by_status[:queued])
            statsd.gauge('outboxer.queue.latency', queue_latency * 1000)

            statsd.gauge('outboxer.messages.queued', messages_count_by_status[:queued])
            statsd.gauge('outboxer.messages.dequeued', messages_count_by_status[:dequeued])
            statsd.gauge('outboxer.messages.publishing', messages_count_by_status[:publishing])
            statsd.gauge('outboxer.messages.failed', messages_count_by_status[:failed])

            metrics.update!(updated_at: current_time)
          end
        end
      end

      nil
    rescue ActiveRecord::LockNotAvailable
      nil
    rescue ActiveRecord::RecordNotFound
      begin
        ActiveRecord::Base.connection_pool.with_connection do |connection|
          Models::Metrics.lock('FOR UPDATE NOWAIT').create!
        end

        log(statsd: statsd, interval: interval)
      rescue ActiveRecord::RecordNotUnique
        log(statsd: statsd, interval: interval)
      end
    end
  end
end
