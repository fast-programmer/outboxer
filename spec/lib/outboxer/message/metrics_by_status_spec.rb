require "rails_helper"

module Outboxer
  RSpec.describe Message do
    describe ".metrics_by_status" do
      let(:current_utc_time) { Time.utc(2025, 1, 1, 0, 0, 0) }

      before do
        Models::Thread.delete_all
        Models::Message.delete_all
      end

      before do
        create(
          :outboxer_thread,
          :historic,
          queued_message_count: 10,
          publishing_message_count: 20,
          published_message_count: 30,
          failed_message_count: 40,
          published_message_count_last_updated_at: current_utc_time
        )

        create(
          :outboxer_thread,
          hostname: "worker5.test.local",
          process_id: 555,
          thread_id: 25_001,
          queued_message_count: 5,
          publishing_message_count: 6,
          published_message_count: 7,
          failed_message_count: 8,
          published_message_count_last_updated_at: current_utc_time
        )
      end

      it "returns metrics by status" do
        expect(
          Message.metrics_by_status(time: double(now: current_utc_time))
        ).to eq(
          queued: {
            count: 15,
            age: 0,
            latency: 0
          },
          publishing: {
            count: 26,
            age: 0,
            latency: nil
          },
          published: {
            count: 37,
            age: 0,
            latency: nil
          },
          failed: {
            count: 48,
            age: 0,
            latency: nil
          },
          total: {
            count: 126,
            age: 0,
            latency: nil
          }
        )
      end
    end
  end
end
