require "rails_helper"

module Outboxer
  RSpec.describe Publisher do
    describe ".terminate" do
      it "sets publisher status to TERMINATING" do
        Publisher.terminate(id: 1)

        expect(Publisher.terminating?).to eq(true)
      end
    end
  end
end
