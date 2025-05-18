require "rails_helper"

module Outboxer
  RSpec.describe Publisher do
    describe ".stop" do
      let(:publisher) { create(:outboxer_publisher, status: Models::Publisher::Status::PUBLISHING) }
      let(:now) { Time.now.utc }

      it "sets publisher status to STOPPED" do
        Publisher.stop(id: publisher.id, time: class_double(Time, now: now))

        expect(Models::Publisher.find(publisher.id).status)
          .to eq(Models::Publisher::Status::STOPPED)
      end
    end
  end
end
