require "spec_helper"

module Outboxer
  RSpec.describe Messages do
    describe ".list" do
      context "when time_zone invalid" do
        it "raises an ArgumentError" do
          expect do
            Messages.list(time_zone: "invalid")
          end.to raise_error(ArgumentError, "time_zone must be valid")
        end
      end
    end
  end
end
