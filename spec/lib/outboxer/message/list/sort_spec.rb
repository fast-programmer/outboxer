require "rails_helper"

module Outboxer
  RSpec.describe Message do
    let!(:message_1) do
      create(:outboxer_message, :queued,
        messageable_type: "Event", messageable_id: "1",
        updated_at: 10.seconds.ago)
    end

    let!(:message_2) do
      create(:outboxer_message, :failed, messageable_type: "Event", messageable_id: "2",
        updated_at: 9.seconds.ago)
    end

    let!(:message_4) do
      create(:outboxer_message, :queued, messageable_type: "Event", messageable_id: "4",
        updated_at: 7.seconds.ago)
    end

    let!(:message_5) do
      create(:outboxer_message, :publishing, messageable_type: "Event", messageable_id: "5",
        updated_at: 6.seconds.ago)
    end

    describe ".list" do
      context "when an invalid sort is specified" do
        it "raises an ArgumentError" do
          expect do
            Message.list(sort: :invalid)
          end.to raise_error(
            ArgumentError, "sort must be id status messageable queued_at updated_at publisher_name")
        end
      end

      context "when an invalid order is specified" do
        it "raises an ArgumentError" do
          expect do
            Message.list(order: :invalid)
          end.to raise_error(ArgumentError, "order must be asc desc")
        end
      end

      context "with sort by status" do
        it "sorts messages by status in ascending order" do
          expect(
            Message
              .list(sort: :status, order: :asc)[:messages]
              .map { |message| message[:status] }).to eq([:failed, :publishing, :queued, :queued])
        end

        it "sorts messages by status in descending order" do
          expect(
            Message
              .list(sort: :status, order: :desc)[:messages]
              .map { |message| message[:status] }).to eq([:queued, :queued, :publishing, :failed])
        end
      end

      context "with sort by messageable" do
        it "sorts messages by messageable in ascending order" do
          expect(
            Message
              .list(sort: :messageable, order: :asc)[:messages]
              .map do |message|
                [message[:messageable_type], message[:messageable_id]]
              end).to eq([["Event", "1"], ["Event", "2"], ["Event", "4"],
                          ["Event", "5"]])
        end

        it "sorts messages by messageable in descending order" do
          expect(
            Message
              .list(sort: :messageable, order: :desc)[:messages]
              .map do |message|
                [message[:messageable_type], message[:messageable_id]]
              end).to eq([["Event", "5"], ["Event", "4"], ["Event", "2"], ["Event", "1"]])
        end
      end

      context "with sort by queued_at" do
        it "sorts messages by queued_at in ascending order" do
          expect(
            Message
              .list(sort: :queued_at, order: :asc)[:messages]
              .map { |message| message[:id] }).to eq([1, 2, 3, 4])
        end

        it "sorts messages by queued_at in descending order" do
          expect(
            Message
              .list(sort: :queued_at, order: :desc)[:messages]
              .map { |message| message[:id] }).to eq([4, 3, 2, 1])
        end
      end

      context "with sort by updated_at" do
        it "sorts messages by updated_at in ascending order" do
          expect(
            Message
              .list(sort: :updated_at, order: :asc)[:messages]
              .map { |message| message[:id] }).to eq([1, 2, 3, 4])
        end

        it "sorts messages by updated_at in descending order" do
          expect(
            Message
              .list(sort: :updated_at, order: :desc)[:messages]
              .map { |message| message[:id] }).to eq([4, 3, 2, 1])
        end
      end
    end
  end
end
