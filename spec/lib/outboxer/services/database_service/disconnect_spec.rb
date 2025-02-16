require "rails_helper"

module Outboxer
  RSpec.describe DatabaseService do
    describe ".disconnect" do
      context "when successful" do
        it "does not raise an error" do
          expect { DatabaseService.disconnect(logger: nil) }.not_to raise_error
        end

        it "returns connected false" do
          DatabaseService.disconnect(logger: nil)

          expect(DatabaseService.connected?).to be false
        end
      end
    end
  end
end
