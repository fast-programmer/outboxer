require 'spec_helper'

module Outboxer
  RSpec.describe Publisher do
    describe '.pop_message!' do
      context 'when a queued message is in the queue' do
        let(:queue) { Queue.new }
        let(:logger) { instance_double(Logger, debug: true, error: true) }

        let(:message) { create(:outboxer_message, :queued) }

        before do
          queue.push(message)
        end

        it 'processes the message' do
          Publisher.pop_message!(queue: queue, logger: logger) do |msg|
            expect(msg.messageable_type).to eq('Event')
            expect(msg.id).to eq(message.id)
          end
        end

        it 'deletes the message' do
          Publisher.pop_message!(queue: queue, logger: logger) { |msg| }

          expect(Models::Message.count).to eq(0)
        end
      end

      context 'when an error occurs during processing' do
        let(:queue) { Queue.new }
        let(:logger) { instance_double(Logger, debug: true, error: true) }

        let(:message) { create(:outboxer_message, :queued) }

        let(:error) { StandardError.new('processing error') }

        before do
          queue.push(message)
        end

        it 'logs the error' do
          expect(logger).to receive(:error)
            .with("Message publishing failed { id: #{message.id}, error: #{error} }")

          begin
            Publisher.pop_message!(queue: queue, logger: logger) { |_msg| raise error }
          rescue StandardError
            # ignore
          end
        end

        it 'updates the message and creates associated exception' do
          begin
            Publisher.pop_message!(queue: queue, logger: logger) { |_msg| raise error }
          rescue StandardError
            # ignore
          end

          updated_outboxer_message = Models::Message.find(message.id)
          expect(updated_outboxer_message.status).to eq(Models::Message::Status::FAILED)
          expect(updated_outboxer_message.exceptions.count).to eq(1)
          expect(updated_outboxer_message.exceptions.first.class_name).to eq(error.class.name)
          expect(updated_outboxer_message.exceptions.first.message_text).to eq(error.message)
          expect(updated_outboxer_message.exceptions.first.frames).to be_present
        end

        it 're-raises error' do
          expect do
            Publisher.pop_message!(queue: queue, logger: logger) { |_msg| raise error }
          end.to raise_error(error)
        end
      end

      context 'when nil is pushed' do
        let(:queue) { Queue.new }
        let(:logger) { instance_double(Logger, debug: true, error: true) }

        before do
          queue.push(nil)
        end

        it 'raises ThreadAborted' do
          expect do
            Publisher.pop_message!(queue: queue, logger: logger) { |_msg| 'processed' }
          end.to raise_error(Publisher::ThreadAborted)
        end
      end
    end
  end
end
