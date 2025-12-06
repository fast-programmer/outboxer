require "rails_helper"

module Outboxer
  RSpec.describe Message do
    describe ".metrics_by_status" do
      let(:current_utc_time) { Time.utc(2025, 1, 1, 0, 0, 0) }

      before { Models::Message::Counter.delete_all }

      before do
        create(
          :outboxer_message_counter,
          :historic,
          queued_count: 10,
          publishing_count: 20,
          published_count: 30,
          failed_count: 40,
          created_at: current_utc_time,
          updated_at: current_utc_time
        )

        create(
          :outboxer_message_counter,
          hostname: "worker5.test.local",
          process_id: 555,
          thread_id: 25_001,
          queued_count: 5,
          publishing_count: 6,
          published_count: 7,
          failed_count: 8,
          created_at: current_utc_time,
          updated_at: current_utc_time
        )
      end

      it "returns metrics by status" do
        expect(Message.metrics_by_status).to eq(
          queued: { count: 15, latency: 0 },
          publishing: { count: 26, latency: 0 },
          published: { count: 37, latency: 0 },
          failed: { count: 48, latency: 0 },
          total: { count: 126, latency: 0 }
        )
      end
    end
  end
end
