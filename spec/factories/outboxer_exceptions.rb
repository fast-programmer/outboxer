FactoryBot.define do
  factory :outboxer_exception, class: 'Outboxer::Models::Exception' do
    class_name { 'NoMethodError' }
    message_text { 'undefined method `method_name' }
    created_at { DateTime.parse("2024-03-16T12:00:00") }
  end
end
