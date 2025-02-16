require "rails_helper"

module Outboxer
  RSpec.describe DatabaseService do
    describe ".connect" do
      before(:each) { DatabaseService.disconnect(logger: nil) }

      after(:all) do
        config = DatabaseService.config(environment: "test", pool: 20)
        DatabaseService.connect(config: config, logger: nil)
      end

      context "when db config valid" do
        let(:config) { DatabaseService.config(environment: "test", pool: 20) }

        it "establishes a connection without errors" do
          expect do
            DatabaseService.connect(config: config, logger: nil)
          end.not_to raise_error
        end

        it "actually connects to the database" do
          DatabaseService.connect(config: config, logger: nil)

          expect(DatabaseService.connected?).to be true
        end
      end
    end
  end
end
