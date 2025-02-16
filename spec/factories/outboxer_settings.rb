FactoryBot.define do
  factory :outboxer_setting, class: "Outboxer::Setting" do
    name { "messages.published.count.historic" }
    value { 500 }
  end
end
