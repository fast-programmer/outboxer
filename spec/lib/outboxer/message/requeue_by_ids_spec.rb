require "rails_helper"

module Outboxer
  RSpec.describe Message do
    describe ".requeue_by_ids" do
      let!(:message_1) { create(:outboxer_message, :failed) }
      let!(:exception_1) { create(:outboxer_exception, message: message_1) }
      let!(:frame_1) { create(:outboxer_frame, exception: exception_1) }

      let!(:message_2) { create(:outboxer_message, :failed) }
      let!(:exception_2) { create(:outboxer_exception, message: message_2) }
      let!(:frame_2) { create(:outboxer_frame, exception: exception_2) }

      let!(:ids) { [message_1.id, message_2.id] }

      describe "when ids exist" do
        let!(:result) { Message.requeue_by_ids(ids: ids) }

        it "sets message status to queued" do
          expect(
            Models::Message
              .where(status: Message::Status::QUEUED)
              .order(id: :asc)
              .pluck(:id)).to eq(ids)
        end

        it "returns correct result" do
          expect(result).to eq({ requeued_count: ids.count, not_requeued_ids: [] })
        end
      end

      describe "when an id does not exist" do
        let(:non_existent_id) { 5 }
        let(:result) { Message.requeue_by_ids(ids: [non_existent_id]) }

        it "does not delete selected messages" do
          expect(Models::Frame.count).to eq(2)
          expect(Models::Exception.count).to eq(2)
          expect(Models::Message.count).to eq(2)
        end

        it "returns correct result" do
          expect(result).to eq({ requeued_count: 0, not_requeued_ids: [non_existent_id] })
        end
      end
    end
  end
end
