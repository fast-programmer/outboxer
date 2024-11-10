FactoryBot.define do
  factory :outboxer_signal, class: 'Outboxer::Models::Signal' do
    name { 'TSTP' }
  end
end
