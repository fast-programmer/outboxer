require 'spec_helper'

module Outboxer
  RSpec.describe Messages do
    # before do
    #   create(:outboxer_message, id: 4, status: :backlogged,
    #     messageable_type: 'Event', messageable_id: 1,
    #     created_at: 5.minutes.ago, updated_at: 4.minutes.ago)
    #   create(:outboxer_message, id: 3, status: :failed,
    #     messageable_type: 'Event', messageable_id: 2,
    #     created_at: 4.minutes.ago, updated_at: 3.minutes.ago)
    #   create(:outboxer_message, id: 2, status: :queued,
    #     messageable_type: 'Event', messageable_id: 3,
    #     created_at: 3.minutes.ago, updated_at: 2.minutes.ago)
    #   create(:outboxer_message, id: 1, status: :backlogged,
    #     messageable_type: 'Event', messageable_id: 4,
    #     created_at: 2.minutes.ago, updated_at: 1.minute.ago)
    # end

    let!(:message_1) do
      create(:outboxer_message, :backlogged, messageable_type: 'Event', messageable_id: '1')
    end

    let!(:message_2) do
      create(:outboxer_message, :failed, messageable_type: 'Event', messageable_id: '2')
    end

    let!(:message_3) do
      create(:outboxer_message, :queued, messageable_type: 'Event', messageable_id: '3')
    end

    let!(:message_4) do
      create(:outboxer_message, :backlogged, messageable_type: 'Event', messageable_id: '4')
    end

    let!(:message_5) do
      create(:outboxer_message, :publishing, messageable_type: 'Event', messageable_id: '5')
    end

    describe '.list' do
      context 'when an invalid sort is specified' do
        it 'raises an ArgumentError' do
          expect do
            Messages.list(sort: :invalid)
          end.to raise_error(
            ArgumentError, "sort must be id status messageable created_at updated_at")
        end
      end

      context 'when an invalid order is specified' do
        it 'raises an ArgumentError' do
          expect do
            Messages.list(order: :invalid)
          end.to raise_error(ArgumentError, "order must be asc desc")
        end
      end

      context 'with sort by status' do
        it 'sorts messages by status in ascending order' do
          expect(
            Messages
              .list(sort: :status, order: :asc)[:messages]
              .map { |message| message[:status] }
          ).to eq([:backlogged, :backlogged, :failed, :publishing, :queued])
        end

        it 'sorts messages by status in descending order' do
          expect(
            Messages
              .list(sort: :status, order: :desc)[:messages]
              .map { |message| message[:status] }
          ).to eq([:queued, :publishing, :failed, :backlogged, :backlogged])
        end
      end

      context 'with sort by messageable' do
        it 'sorts messages by messageable in ascending order' do
          expect(
            Messages
              .list(sort: :messageable, order: :asc)[:messages]
              .map { |message| [message[:messageable_type], message[:messageable_id]] }
          ).to eq([['Event', '1'], ['Event', '2'], ['Event', '3'], ['Event', '4'], ['Event', '5']])
        end

        it 'sorts messages by messageable in descending order' do
          expect(
            Messages
              .list(sort: :messageable, order: :desc)[:messages]
              .map { |message| [message[:messageable_type], message[:messageable_id]] }
          ).to eq([['Event', '5'], ['Event', '4'], ['Event', '3'], ['Event', '2'], ['Event', '1']])
        end
      end

      context 'with sort by created_at' do
        it 'sorts messages by created_at in ascending order' do
          expect(
            Messages
              .list(sort: :created_at, order: :asc)[:messages]
              .map { |message| message[:id] }
          ).to eq([1, 2, 3, 4, 5])
        end

        it 'sorts messages by created_at in descending order' do
          expect(
            Messages
              .list(sort: :created_at, order: :desc)[:messages]
              .map { |message| message[:id] }
          ).to eq([5, 4, 3, 2, 1])
        end
      end

      context 'with sort by updated_at' do
        it 'sorts messages by updated_at in ascending order' do
          expect(
            Messages
              .list(sort: :updated_at, order: :asc)[:messages]
              .map { |message| message[:id] }
          ).to eq([1, 2, 3, 4, 5])
        end

        it 'sorts messages by updated_at in descending order' do
          expect(
            Messages
              .list(sort: :updated_at, order: :desc)[:messages]
              .map { |message| message[:id] }
          ).to eq([5, 4, 3, 2, 1])
        end
      end
    end
  end
end
