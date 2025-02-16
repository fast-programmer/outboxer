require "rails_helper"

module Outboxer
  RSpec.describe Messages do
    before do
      create_list(:outboxer_message, 101, status: :queued,
        messageable_type: "Event", messageable_id: 1)
    end

    describe ".list" do
      let(:first_page) { Messages.list(page: 1, per_page: 100) }
      let(:second_page) { Messages.list(page: 2, per_page: 100) }

      context "when invalid per page is specified" do
        it "raises an ArgumentError" do
          expect do
            Messages.list(per_page: 1)
          end.to raise_error(ArgumentError, "per_page must be 10 100 200 500 1000")
        end
      end

      context "when invalid page is specified" do
        it "raises an ArgumentError" do
          expect do
            Messages.list(page: "hello")
          end.to raise_error(ArgumentError, "page must be >= 1")
        end
      end

      context "when 100 messages per page" do
        it "first page returns 100 messages" do
          expect(first_page[:messages].size).to eq(100)
        end

        it "second page returns 1 message" do
          expect(second_page[:messages].size).to eq(1)
        end

        it "ensures no overlap between first and second page" do
          first_page_ids = first_page[:messages].map { |message| message[:id] }
          second_page_ids = second_page[:messages].map { |message| message[:id] }
          expect(first_page_ids & second_page_ids).to be_empty
        end
      end
    end
  end
end
