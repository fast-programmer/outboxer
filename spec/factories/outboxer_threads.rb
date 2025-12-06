FactoryBot.define do
  factory :outboxer_thread, class: "Outboxer::Models::Thread" do
    hostname   { Socket.gethostname }
    process_id { Process.pid }
    thread_id  { Thread.current.object_id }

    queued_count       { 0 }
    publishing_count   { 0 }
    published_count    { 0 }
    failed_count       { 0 }

    current_time = Time.now.utc
    queued_count_last_updated_at       { current_time }
    publishing_count_last_updated_at   { current_time }
    published_count_last_updated_at    { current_time }
    failed_count_last_updated_at       { current_time }

    created_at { current_time - 10.seconds }
    updated_at { current_time - 5.seconds }

    trait :historic do
      hostname   { Outboxer::Models::Thread::HISTORIC_HOSTNAME }
      process_id { Outboxer::Models::Thread::HISTORIC_PROCESS_ID }
      thread_id  { Outboxer::Models::Thread::HISTORIC_THREAD_ID }
    end

    trait :thread do
      hostname   { Socket.gethostname }
      process_id { Process.pid }
      thread_id  { Thread.current.object_id }
    end
  end
end
