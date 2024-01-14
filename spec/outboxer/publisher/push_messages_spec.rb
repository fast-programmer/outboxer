require 'spec_helper'

module Outboxer
  RSpec.describe Publisher do
    describe '.push_messages!' do
      context 'when an unpublished message has been created' do
        let(:queue) { Queue.new }
        let(:logger) { instance_double(Logger, debug: true, error: true) }
        let(:threads) { [] }
        let(:queue_max) { 1 }
        let(:poll) { 1 }
        let(:kernel) { class_double(Kernel, sleep: nil) }

        let!(:message) do
          Models::Message.create!(
            outboxer_messageable_type: 'DummyType',
            outboxer_messageable_id: 2,
            status: Models::Message::STATUS[:unpublished])
        end

        before do
          Publisher.push_messages!(
            threads: threads,
            queue: queue,
            queue_max: queue_max,
            poll: poll,
            logger: logger,
            kernel: kernel)
        end

        it 'adds messages to the queue' do
          expect(queue.size).to eq(1)
        end

        it 'sleeps due to queue full' do
          expect(kernel).to have_received(:sleep).with(poll)
        end
      end

      context 'when no messages exist' do
        let(:queue) { Queue.new }
        let(:logger) { instance_double(Logger, debug: true, error: true) }
        let(:threads) { [] }
        let(:queue_max) { 1 }
        let(:poll) { 1 }
        let(:kernel) { class_double(Kernel) }

        before do
          allow(kernel).to receive(:sleep)

          Publisher.push_messages!(
            threads: threads, queue: queue, queue_max: queue_max, poll: poll, logger: logger,
            kernel: kernel)
        end

        it 'calls sleep once' do
          expect(kernel).to have_received(:sleep).with(poll).once
        end

        it 'does not change the queue size from 0' do
          expect(queue.size).to eq(0)
        end
      end

      context 'when queue is full' do
        let(:queue) { Queue.new }
        let(:logger) { instance_double(Logger, debug: true, error: true) }
        let(:threads) { [] }
        let(:queue_max) { 1 }
        let(:poll) { 1 }
        let(:kernel) { class_double(Kernel, sleep: nil) }

        let(:message) do
          Models::Message.create!(
            outboxer_messageable_type: 'DummyType',
            outboxer_messageable_id: 1,
            status: Models::Message::STATUS[:publishing])
        end

        before do
          allow(kernel).to receive(:sleep)

          queue.push(message)

          Publisher.push_messages!(
            threads: threads, queue: queue, queue_max: queue_max, poll: poll, logger: logger,
            kernel: kernel)
        end

        it 'calls sleep once' do
          expect(kernel).to have_received(:sleep).with(poll).once
        end

        it 'does not change the queue size from 1' do
          expect(queue.size).to eq(1)
        end
      end
    end
  end
end
