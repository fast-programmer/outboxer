require "rails_helper"

module Outboxer
  module Models
    RSpec.describe Thread, type: :model do
      let(:now) { Time.now.utc }

      describe ".update_message_counts_by!" do
        context "when the row does not exist (insert path)" do
          it "creates a new row with correct counters and timestamps" do
            Thread.update_message_counts_by!(
              queued_message_count: 1,
              publishing_message_count: 2,
              published_message_count: 3,
              failed_message_count: 4,
              current_utc_time: now
            )

            thread = Thread.find_by!(
              hostname: ::Socket.gethostname,
              process_id: ::Process.pid,
              thread_id: ::Thread.current.object_id)

            expect(thread.queued_message_count).to eq(1)
            expect(thread.publishing_message_count).to eq(2)
            expect(thread.published_message_count).to eq(3)
            expect(thread.failed_message_count).to eq(4)

            expect(thread.queued_message_count_last_updated_at.to_i).to eq(now.to_i)
            expect(thread.publishing_message_count_last_updated_at.to_i).to eq(now.to_i)
            expect(thread.published_message_count_last_updated_at.to_i).to eq(now.to_i)
            expect(thread.failed_message_count_last_updated_at.to_i).to eq(now.to_i)

            expect(thread.created_at.to_i).to eq(now.to_i)
            expect(thread.updated_at.to_i).to eq(now.to_i)
          end
        end

        context "when the row already exists (update path)" do
          let!(:thread) do
            create(
              :outboxer_thread, :current,
              queued_message_count: 10,
              publishing_message_count: 20,
              published_message_count: 30,
              failed_message_count: 40,
              created_at: now - 60,
              updated_at: now - 60)
          end

          it "atomically increments only the provided counters" do
            later = now + 30

            Thread.update_message_counts_by!(
              queued_message_count: 5, failed_message_count: 2, current_utc_time: later)

            thread.reload

            expect(thread.queued_message_count).to eq(15)
            expect(thread.failed_message_count).to eq(42)

            expect(thread.publishing_message_count).to eq(20)
            expect(thread.published_message_count).to eq(30)

            expect(thread.queued_message_count_last_updated_at.to_i).to eq(later.to_i)
            expect(thread.failed_message_count_last_updated_at.to_i).to eq(later.to_i)
            expect(thread.updated_at.to_i).to eq(later.to_i)
          end
        end

        context "when all deltas are zero" do
          let!(:thread) do
            create(:outboxer_thread, :current,
              queued_message_count: 1,
              publishing_message_count: 1,
              published_message_count: 1,
              failed_message_count: 1,
              created_at: now - 60,
              updated_at: now - 60
            )
          end

          it "only updates updated_at" do
            later = now + 10

            Thread.update_message_counts_by!(current_utc_time: later)

            thread.reload

            expect(thread.queued_message_count).to eq(1)
            expect(thread.publishing_message_count).to eq(1)
            expect(thread.published_message_count).to eq(1)
            expect(thread.failed_message_count).to eq(1)

            expect(thread.updated_at.to_i).to eq(later.to_i)
          end
        end
      end
    end
  end
end
