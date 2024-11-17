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
    end

    trait :buffered do
      status { Outboxer::Models::Message::Status::BUFFERED }

      buffered_at { 23.hours.ago }
    end

    trait :publishing do
      status { Outboxer::Models::Message::Status::PUBLISHING }

      buffered_at { 23.hours.ago }
    end

    trait :published do
      status { Outboxer::Models::Message::Status::PUBLISHED }

      buffered_at { 23.hours.ago }
    end

    trait :failed do
      buffered_at { 23.hours.ago }

      status { Outboxer::Models::Message::Status::FAILED }
    end
  end
end
