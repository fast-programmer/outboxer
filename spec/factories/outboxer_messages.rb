FactoryBot.define do
  factory :outboxer_message, class: "Outboxer::Models::Message" do
    messageable_type { "Event" }
    messageable_id { 1 }

    status { Outboxer::Message::Status::PUBLISHED }
    queued_at { 10.seconds.ago }
    publishing_at { 8.seconds.ago }
    updated_at { 7.seconds.ago }

    publisher_id { 5 }
    publisher_name { "server-01:47000" }

    trait :queued do
      status { Outboxer::Message::Status::QUEUED }

      queued_at { 10.seconds.ago }
      updated_at { 10.seconds.ago }
    end

    trait :publishing do
      status { Outboxer::Message::Status::PUBLISHING }

      queued_at { 10.seconds.ago }
      publishing_at { 8.seconds.ago }
      updated_at { 8.seconds.ago }
    end

    trait :published do
      status { Outboxer::Message::Status::PUBLISHED }

      queued_at { 10.seconds.ago }
      publishing_at { 8.seconds.ago }
      updated_at { 7.seconds.ago }
    end

    trait :failed do
      status { Outboxer::Message::Status::FAILED }

      queued_at { 10.seconds.ago }
      publishing_at { 8.seconds.ago }
      updated_at { 7.seconds.ago }
    end
  end
end
