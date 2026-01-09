require "aws-sdk-cloudwatch"

# env = ENV["APP_ENV"] || ENV["RAILS_ENV"] || "development"

running = true

["TERM", "INT"].each do |sig|
  Signal.trap(sig) { running = false }
end

cloud_watch = Aws::CloudWatch::Client.new

interval = 10
tick = 1

while running
  metrics_by_status = Outboxer::Message.metrics_by_status

  cloud_watch.put_metric_data(
    namespace: "Outboxer",
    metric_data: [
      {
        metric_name: "MessagesQueuedCount",
        value: metrics_by_status[:queued][:count],
        unit: "Count"
      },
      {
        metric_name: "MessagesQueuedLatencySeconds",
        value: metrics_by_status[:queued][:latency] || 0,
        unit: "Seconds"
      }
    ]
  )

  slept = 0

  while running && slept < interval
    sleep tick

    slept += tick
  end
end
