require "rails_helper"

module Outboxer
  RSpec.describe Setting, type: :module do
    describe ".create_all" do
      it "creates setting" do
        Setting.create_all

        expect(Models::Setting.find_by(name: "messages.published.count.historic").value).to eq("0")
        expect(Models::Setting.find_by(name: "messages.failed.count.historic").value).to eq("0")
      end
    end
  end
end
