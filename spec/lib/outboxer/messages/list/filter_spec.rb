require 'spec_helper'

module Outboxer
  RSpec.describe Messages do
    before do
      create(:outboxer_message, :unpublished, id: 4,
        messageable_type: 'Event', messageable_id: 1,
        created_at: 5.minutes.ago, updated_at: 4.minutes.ago)
      create(:outboxer_message, :failed, id: 3,
        messageable_type: 'Event', messageable_id: 2,
        created_at: 4.minutes.ago, updated_at: 3.minutes.ago)
      create(:outboxer_message, :publishing, id: 2,
        messageable_type: 'Event', messageable_id: 3,
        created_at: 3.minutes.ago, updated_at: 2.minutes.ago)
      create(:outboxer_message, :unpublished, id: 1,
        messageable_type: 'Event', messageable_id: 4,
        created_at: 2.minutes.ago, updated_at: 1.minute.ago)
    end

    describe '.list' do
      context 'when an invalid status is specified' do
        it 'raises an ArgumentError' do
          expect do
            Messages.list(status: :invalid)
          end.to raise_error(
            ArgumentError, "status must be #{Models::Message::STATUSES.join(' ')}")
        end
      end

      context 'with no status specified' do
        it 'returns all messages' do
          expect(
            Messages.list(sort: :status, order: :asc)
          ).to match_array([
            {
              'id' => 3,
              'status' => 'failed',
              'messageable' => 'Event::2',
              'created_at' => 4.minutes.ago.utc.to_s,
              'updated_at' => 3.minutes.ago.utc.to_s
            },
            {
              'id' => 2,
              'status' => 'publishing',
              'messageable' => 'Event::3',
              'created_at' => 3.minutes.ago.utc.to_s,
              'updated_at' => 2.minutes.ago.utc.to_s
            },
            {
              'id' => 4,
              'status' => 'unpublished',
              'messageable' => 'Event::1',
              'created_at' => 5.minutes.ago.utc.to_s,
              'updated_at' => 4.minutes.ago.utc.to_s
            },
            {
              'id' => 1,
              'status' => 'unpublished',
              'messageable' => 'Event::4',
              'created_at' => 2.minutes.ago.utc.to_s,
              'updated_at' => 1.minute.ago.utc.to_s
            }
          ])
        end
      end

      context 'with unpublished status' do
        it 'returns unpublished messages' do
          expect(
            Messages.list(status: :unpublished, sort: :status, order: :asc)
          ).to match_array([
            {
              'id' => 4,
              'status' => 'unpublished',
              'messageable' => 'Event::1',
              'created_at' => 5.minutes.ago.utc.to_s,
              'updated_at' => 4.minutes.ago.utc.to_s
            },
            {
              'id' => 1,
              'status' => 'unpublished',
              'messageable' => 'Event::4',
              'created_at' => 2.minutes.ago.utc.to_s,
              'updated_at' => 1.minute.ago.utc.to_s
            }
          ])
        end
      end

      context 'with publishing status' do
        it 'returns publishing messages' do
          expect(
            Messages.list(status: :publishing, sort: :status, order: :asc)
          ).to match_array([
            {
              'id' => 2,
              'status' => 'publishing',
              'messageable' => 'Event::3',
              'created_at' => 3.minutes.ago.utc.to_s,
              'updated_at' => 2.minutes.ago.utc.to_s
            }
          ])
        end
      end

      context 'with failed status' do
        it 'returns failed messages' do
          expect(
            Messages.list(status: :failed, sort: :status, order: :asc)
          ).to match_array([
            {
              'id' => 3,
              'status' => 'failed',
              'messageable' => 'Event::2',
              'created_at' => 4.minutes.ago.utc.to_s,
              'updated_at' => 3.minutes.ago.utc.to_s
            }
          ])
        end
      end
    end
  end
end
