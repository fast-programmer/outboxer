FactoryBot.define do
  factory :outboxer_message, class: 'Outboxer::Models::Message' do
    messageable_type { 'Event' }
    messageable_id { 1 }
    status { Outboxer::Models::Message::Status::QUEUED }
    queued_at { 1.day.ago }
    updated_at { 1.day.ago }
    updated_by_publisher_id { 5 }
    updated_by_publisher_name { 'server-01:47000' }

    trait :queued do
      status { Outboxer::Models::Message::Status::QUEUED }

      queued_at { 1.day.ago }
    end

    trait :buffered do
      status { Outboxer::Models::Message::Status::BUFFERED }

      queued_at { 24.hours.ago }
      buffered_at { 22.hours.ago }
      publishing_at { nil }
      updated_at { 22.hours.ago }
    end

    trait :publishing do
      status { Outboxer::Models::Message::Status::PUBLISHING }

      queued_at { 24.hours.ago }
      buffered_at { 22.hours.ago }
      publishing_at { 23.hours.ago }
      updated_at { 22.hours.ago }
    end

    trait :published do
      status { Outboxer::Models::Message::Status::PUBLISHED }

      queued_at { 24.hours.ago }
      buffered_at { 22.hours.ago }
      publishing_at { 23.hours.ago }
      updated_at { 24.hours.ago }
    end

    trait :failed do
      status { Outboxer::Models::Message::Status::FAILED }

      queued_at { 24.hours.ago }
      buffered_at { 22.hours.ago }
      publishing_at { 23.hours.ago }
      updated_at { 24.hours.ago }
    end
  end
end
