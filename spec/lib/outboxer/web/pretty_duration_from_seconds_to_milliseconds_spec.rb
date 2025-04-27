require "rails_helper"

require_relative "../../../../lib/outboxer/web"

module Outboxer
  RSpec.describe Web do
    context "pretty_duration_from_seconds_to_milliseconds" do
      it "returns '-' when seconds is zero" do
        expect(
          Web.pretty_duration_from_seconds_to_milliseconds(seconds: 0)
        ).to eq("-")
      end

      it "returns milliseconds when less than one second" do
        expect(
          Web.pretty_duration_from_seconds_to_milliseconds(seconds: 0.5)
        ).to eq("500ms")
      end

      it "returns '1s' when exactly one second" do
        expect(
          Web.pretty_duration_from_seconds_to_milliseconds(seconds: 1)
        ).to eq("1s")
      end

      it "returns '1min 123ms' when one minute and some milliseconds" do
        expect(
          Web.pretty_duration_from_seconds_to_milliseconds(seconds: 60.123)
        ).to eq("1min 123ms")
      end

      it "returns '1h' when one hour" do
        expect(
          Web.pretty_duration_from_seconds_to_milliseconds(seconds: 3600)
        ).to eq("1h")
      end

      it "returns '1d 789ms' when one day and some milliseconds" do
        expect(
          Web.pretty_duration_from_seconds_to_milliseconds(seconds: 86_400.789)
        ).to eq("1d 789ms")
      end

      it "returns '1y' when large value (1 year)" do
        expect(
          Web.pretty_duration_from_seconds_to_milliseconds(seconds: 31_536_000)
        ).to eq("1y")
      end
    end
  end
end
