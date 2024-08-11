FactoryBot.define do
  factory :outboxer_metric, class: 'Outboxer::Models::Metric' do
    name { 'messages.published.count.historic' }
    value { BigDecimal('500') }
  end
end
