require "rails_helper"

module Outboxer
  RSpec.describe SettingService, type: :module do
    describe ".create" do
      it "creates setting" do
        SettingService.create

        expect(Setting.find_by(name: "messages.published.count.historic").value).to eq("0")
        expect(Setting.find_by(name: "messages.failed.count.historic").value).to eq("0")
      end
    end
  end
end
