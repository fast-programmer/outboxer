FactoryBot.define do
  factory :outboxer_message, class: 'Outboxer::Models::Message' do
    messageable_type { 'Event' }
    messageable_id { 1 }
    status { Outboxer::Models::Message::Status::QUEUED }
    created_at { 1.day.ago }
    updated_by_publisher_id { 5 }
    updated_by_publisher_name { 'server-01:47000' }

    trait :queued do
      status { Outboxer::Models::Message::Status::QUEUED }
    end

    trait :buffered do
      status { Outboxer::Models::Message::Status::BUFFERED }
    end

    trait :publishing do
      status { Outboxer::Models::Message::Status::PUBLISHING }
    end

    trait :published do
      status { Outboxer::Models::Message::Status::PUBLISHED }
    end

    trait :failed do
      status { Outboxer::Models::Message::Status::FAILED }
    end
  end
end
