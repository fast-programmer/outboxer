FactoryBot.define do
  factory :outboxer_thread, class: "Outboxer::Models::Thread" do
    hostname   { Socket.gethostname }
    process_id { Process.pid }
    thread_id  { Thread.current.object_id }

    queued_message_count       { 0 }
    publishing_message_count   { 0 }
    published_message_count    { 0 }
    failed_message_count       { 0 }

    current_time = Time.now.utc
    queued_message_count_last_updated_at       { current_time }
    publishing_message_count_last_updated_at   { current_time }
    published_message_count_last_updated_at    { current_time }
    failed_message_count_last_updated_at       { current_time }

    created_at { current_time - 10.seconds }
    updated_at { current_time - 5.seconds }

    trait :historic do
      hostname   { Outboxer::Models::Thread::HISTORIC_HOSTNAME }
      process_id { Outboxer::Models::Thread::HISTORIC_PROCESS_ID }
      thread_id  { Outboxer::Models::Thread::HISTORIC_THREAD_ID }
    end

    trait :current do
      hostname   { Socket.gethostname }
      process_id { Process.pid }
      thread_id  { Thread.current.object_id }
    end
  end
end
