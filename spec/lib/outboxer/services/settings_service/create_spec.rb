require "rails_helper"

module Outboxer
  RSpec.describe Settings, type: :module do
    describe ".create" do
      it "creates setting" do
        Settings.create

        expect(Models::Setting.find_by(name: "messages.published.count.historic").value).to eq("0")
        expect(Models::Setting.find_by(name: "messages.failed.count.historic").value).to eq("0")
      end
    end
  end
end
