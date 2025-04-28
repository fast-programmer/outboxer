FactoryBot.define do
  factory :outboxer_publisher, class: "Outboxer::Models::Publisher" do
    name { "server-01:57000" }
    status { Outboxer::Publisher::Status::PUBLISHING }
    settings do
      {
        "buffer_size" => 1000,
        "concurrency" => 3,
        "tick_interval" => 0.1,
        "poll_interval" => 5.0,
        "heartbeat_interval" => 5
      }
    end
    metrics do
      {
        "throughput" => 1000,
        "latency" => 0,
        "cpu" => 10.5,
        "rss" => 40.95,
        "rtt" => 3.35
      }
    end
    created_at { DateTime.parse("2024-11-10T00:00:00") }
    updated_at { DateTime.parse("2024-11-10T00:00:00") }

    trait :publishing do
      status { Outboxer::Publisher::Status::PUBLISHING }
    end

    trait :stopped do
      status { Outboxer::Publisher::Status::STOPPED }
    end

    trait :terminating do
      status { Outboxer::Publisher::Status::TERMINATING }
    end
  end
end
