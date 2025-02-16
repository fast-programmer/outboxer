FactoryBot.define do
  factory :outboxer_frame, class: "Outboxer::Frame" do
    index { 1 }
    text { "app/controllers/my_controller.rb:23:in `index`" }
  end
end
