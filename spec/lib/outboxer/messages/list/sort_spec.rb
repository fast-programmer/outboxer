require 'spec_helper'

module Outboxer
  RSpec.describe Messages do
    before do
      create(:outboxer_message, id: 4, status: :unpublished, messageable_type: 'Event',
        messageable_id: 1, created_at: 5.minutes.ago, updated_at: 4.minutes.ago)
      create(:outboxer_message, id: 3, status: :failed, messageable_type: 'Event',
        messageable_id: 2, created_at: 4.minutes.ago, updated_at: 3.minutes.ago)
      create(:outboxer_message, id: 2, status: :publishing, messageable_type: 'Event',
        messageable_id: 3, created_at: 3.minutes.ago, updated_at: 2.minutes.ago)
      create(:outboxer_message, id: 1, status: :unpublished, messageable_type: 'Event',
        messageable_id: 4, created_at: 2.minutes.ago, updated_at: 1.minute.ago)
    end

    describe '.list' do
      context 'with sort by status' do
        it 'sorts messages by status in ascending order' do
          expect(Messages.list(sort: :status, order: :asc).map(&:status)).to eq(
            ['failed', 'publishing', 'unpublished', 'unpublished'])
        end

        it 'sorts messages by status in descending order' do
          expect(Messages.list(sort: :status, order: :desc).map(&:status)).to eq(
            ['unpublished', 'unpublished', 'publishing', 'failed'])
        end
      end

      context 'with sort by messageable' do
        it 'sorts messages by messageable in ascending order' do
          sorted_messages = Messages.list(sort: :messageable, order: :asc)
          expect(sorted_messages.map { |m| [m.messageable_type, m.messageable_id] }).to eq(
            [['TypeA', '1'], ['TypeA', '3'], ['TypeB', '2'], ['TypeC', '4']])
        end

        it 'sorts messages by messageable in descending order' do
          sorted_messages = Messages.list(sort: :messageable, order: :desc)
          expect(sorted_messages.map { |m| [m.messageable_type, m.messageable_id] }).to eq(
            [['TypeC', '4'], ['TypeB', '2'], ['TypeA', '3'], ['TypeA', '1']])
        end
      end

      context 'with sort by created_at' do
        it 'sorts messages by created_at in ascending order' do
          expect(Messages.list(sort: :created_at, order: :asc).map(&:id)).to eq([4, 3, 2, 1])
        end

        it 'sorts messages by created_at in descending order' do
          expect(Messages.list(sort: :created_at, order: :desc).map(&:id)).to eq([1, 2, 3, 4])
        end
      end

      context 'with sort by updated_at' do
        it 'sorts messages by updated_at in ascending order' do
          expect(Messages.list(sort: :updated_at, order: :asc).map(&:id)).to eq([4, 3, 2, 1])
        end

        it 'sorts messages by updated_at in descending order' do
          expect(Messages.list(sort: :updated_at, order: :desc).map(&:id)).to eq([1, 2, 3, 4])
        end
      end
    end
  end
end
