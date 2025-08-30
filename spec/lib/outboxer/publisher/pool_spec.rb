require "rails_helper"

module Outboxer
  RSpec.describe Publisher do
    describe ".pool" do
      it "returns correct value" do
        expect(Publisher.pool(concurrency: 5)).to eql(8)
      end
    end
  end
end
