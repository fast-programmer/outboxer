require "rails_helper"

module Outboxer
  RSpec.describe Message do
    describe ".serialize" do
      it "serializes the arguments into a hash" do
        expect(
          Message.serialize(
            id: 1,
            status: "publishing",
            messageable_type: "Invoice",
            messageable_id: "INV-001",
            updated_at: "2025-05-03T10:00:10Z",
            queued_at: "2025-05-03T10:00:00Z",
            publishing_at: "2025-05-03T10:00:10Z",
            published_at: "2025-05-03T11:00:10Z",
            publisher_id: 42,
            publisher_name: "host.local:12345"
          )
        ).to eq(
          {
            id: 1,
            status: "publishing",
            messageable_type: "Invoice",
            messageable_id: "INV-001",
            updated_at: "2025-05-03T10:00:10Z",
            queued_at: "2025-05-03T10:00:00Z",
            publishing_at: "2025-05-03T10:00:10Z",
            published_at: "2025-05-03T11:00:10Z",
            failed_at: nil,
            publisher_id: 42,
            publisher_name: "host.local:12345"
          }
        )
      end
    end
  end
end
