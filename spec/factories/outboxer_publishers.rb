FactoryBot.define do
  factory :outboxer_publisher, class: 'Outboxer::Models::Publisher' do
    name { 'server-01:57000' }
    status { Outboxer::Models::Publisher::Status::PUBLISHING }
    metrics {
      {
        'throughput' => 1000,
        'latency' => 0,
        'cpu' => '10.5%',
        'rss' => '40.95 MB',
        'rtt' => '3.35 ms'
      }
    }
    created_at { DateTime.parse("2024-11-10T00:00:00") }
    updated_at { DateTime.parse("2024-11-10T00:00:00") }

    trait :publishing do
      status { Outboxer::Models::Publisher::Status::PUBLISHING }
    end

    trait :stopped do
      status { Outboxer::Models::Publisher::Status::STOPPED }
    end

    trait :terminating do
      status { Outboxer::Models::Publisher::Status::TERMINATING }
    end
  end
end
