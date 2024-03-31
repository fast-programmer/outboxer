FactoryBot.define do
  factory :outboxer_message, class: 'Outboxer::Models::Message' do
    messageable_type { 'Event' }
    messageable_id { 1 }
    status { Outboxer::Models::Message::Status::PUBLISHING }
    created_at { 1.day.ago }

    trait :backlogged do
      status { Outboxer::Models::Message::Status::BACKLOGGED }
    end

    trait :publishing do
      status { Outboxer::Models::Message::Status::PUBLISHING }
    end

    trait :failed do
      status { Outboxer::Models::Message::Status::FAILED }
    end
  end
end
