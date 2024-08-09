require 'spec_helper'

module Outboxer
  RSpec.describe Messages do
    describe '.collect_metrics' do
      let(:current_utc_time) { Time.now.utc }

      context 'when there are messages in different statuses' do
        let!(:queued_message) do
          create(:outboxer_message, :queued, updated_at: 5.minutes.ago)
        end

        let!(:dequeued_message) do
          create(:outboxer_message, :dequeued, updated_at: 4.minutes.ago)
        end

        let!(:publishing_message) do
          create(:outboxer_message, :publishing, updated_at: 3.minutes.ago)
        end

        let!(:failed_message) do
          create(:outboxer_message, :failed, updated_at: 10.minutes.ago)
        end

        it 'returns correct metrics' do
          metrics = Messages.collect_metrics(current_utc_time: current_utc_time)

          expect(metrics[:queued][:count]).to eq(1)
          expect(metrics[:queued][:latency]).to eq(
            (current_utc_time - queued_message.updated_at.utc).to_i)

          expect(metrics[:dequeued][:count]).to eq(1)
          expect(metrics[:dequeued][:latency]).to eq(
            (current_utc_time - dequeued_message.updated_at.utc).to_i)

          expect(metrics[:publishing][:count]).to eq(1)
          expect(metrics[:publishing][:latency]).to eq(
            (current_utc_time - publishing_message.updated_at.utc).to_i)

          expect(metrics[:failed][:count]).to eq(1)
          expect(metrics[:failed][:latency]).to eq(
            (current_utc_time - failed_message.updated_at.utc).to_i)
        end
      end

      context 'when there are no messages in a specific status' do
        it 'returns zero count and latency for that status' do
          metrics = Messages.collect_metrics(current_utc_time: current_utc_time)

          expect(metrics[:queued][:count]).to eq(0)
          expect(metrics[:queued][:latency]).to eq(0)

          expect(metrics[:dequeued][:count]).to eq(0)
          expect(metrics[:dequeued][:latency]).to eq(0)

          expect(metrics[:publishing][:count]).to eq(0)
          expect(metrics[:publishing][:latency]).to eq(0)

          expect(metrics[:failed][:count]).to eq(0)
          expect(metrics[:failed][:latency]).to eq(0)
        end
      end

      context 'when no messages exist' do
        it 'returns zero count and latency for all statuses' do
          metrics = Messages.collect_metrics(current_utc_time: current_utc_time)

          Models::Message::STATUSES.each do |status|
            expect(metrics[status.to_sym][:count]).to eq(0)
            expect(metrics[status.to_sym][:latency]).to eq(0)
          end
        end
      end
    end
  end
end
