require "rails_helper"

module Outboxer
  RSpec.describe Database do
    describe ".connect" do
      before(:each) { Database.disconnect(logger: nil) }

      after(:all) do
        config = Database.config(environment: "test", concurrency: 20)
        Database.connect(config: config, logger: nil)
      end

      context "when db config valid" do
        let(:config) { Database.config(environment: "test", concurrency: 20) }

        it "establishes a connection without errors" do
          expect do
            Database.connect(config: config, logger: nil)
          end.not_to raise_error
        end

        it "actually connects to the database" do
          Database.connect(config: config, logger: nil)

          expect(Database.connected?).to be true
        end
      end
    end
  end
end
