FactoryBot.define do
  factory :outboxer_signal, class: "Outboxer::Signal" do
    name { "TSTP" }
  end
end
