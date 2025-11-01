FactoryBot.define do
  factory :outboxer_message_count, class: "Outboxer::Models::Message::Counter" do
    queued     { 0 }
    publishing { 0 }
    published  { 0 }
    failed     { 0 }

    created_at { 10.seconds.ago }
    updated_at { 5.seconds.ago }

    trait :historic do
      hostname   { Outboxer::Message::Count::HISTORIC_HOSTNAME }
      process_id { Outboxer::Message::Count::HISTORIC_PROCESS_ID }
      thread_id  { Outboxer::Message::Count::HISTORIC_THREAD_ID }
    end

    trait :thread do
      hostname { Socket.gethostname }
      process_id { Process.pid }
      thread_id { Thread.current.object_id }
    end
  end
end
