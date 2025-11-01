FactoryBot.define do
  factory :outboxer_counter, class: "Outboxer::Models::Counter" do
    hostname { Socket.gethostname }
    process_id { Process.pid }
    thread_id { Thread.current.object_id }

    queued_count     { 0 }
    publishing_count { 0 }
    published_count  { 0 }
    failed_count     { 0 }

    created_at { 10.seconds.ago }
    updated_at { 5.seconds.ago }

    trait :historic do
      hostname   { Outboxer::Counter::HISTORIC_HOSTNAME }
      process_id { Outboxer::Counter::HISTORIC_PROCESS_ID }
      thread_id  { Outboxer::Counter::HISTORIC_THREAD_ID }
    end
  end
end
