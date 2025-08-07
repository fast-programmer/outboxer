require "sidekiq"
require "connection_pool"

Sidekiq.configure_client do |config|
  config.redis = ConnectionPool.new(size: 5, timeout: 5) do
    Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
  end
end

queue_name = ENV.fetch("SIDEKIQ_QUEUE", "default")

Outboxer::Publisher.publish_messages(batch_size: 1_000, concurrency: 5) do |publisher, messages|
  begin
    job_ids = Sidekiq::Client.push_bulk(
      messages.map do |message|
        {
          "class" => message[:messageable_type].to_s.sub(/Event$/, "Job"),
          "args"  => [message[:messageable_id]],
          "queue" => queue_name
        }
      end)
  rescue => error
    Outboxer::Publisher.update_messages(
      publisher_id: publisher[:id],
      publisher_name: publisher[:name],
      failed_messages: messages.map do |message|
        {
          id: message[:id],
          exception: {
            class_name: error.class.name,
            message_text: error.message,
            backtrace: error.backtrace
          }
        }
      end)
  else
    published_messages, failed_messages = messages.zip(job_ids).partition { |_, job_id| job_id }

    Outboxer::Publisher.update_messages(
      publisher_id: publisher[:id],
      publisher_name: publisher[:name],
      published_message_ids: published_messages.map { |message, _| message[:id] },
      failed_messages: failed_messages.map { |message, _|
        {
          id: message[:id],
          exception: {
            class_name: "RuntimeError",
            message_text: "Job not enqueued (blocked by client middleware)"
          }
        }
      })
  end
end
