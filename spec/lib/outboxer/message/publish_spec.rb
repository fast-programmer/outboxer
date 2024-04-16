require 'spec_helper'

module Outboxer
  RSpec.describe Message do
    describe '.publish' do
      let(:queue) { 1 }
      let(:threads) { 1 }
      let(:poll) { 1 }
      let(:logger) { instance_double(Logger, debug: true, error: true, fatal: true, info: true) }
      let(:kernel) { class_double(Kernel, sleep: nil) }

      before do
        allow(logger).to receive(:level=)
      end

      let!(:backlogged_message) { create(:outboxer_message, :backlogged) }

      context 'when message published successfully' do
        it 'deletes existing message' do
          Message.publish(
            queue: queue,
            threads: threads,
            poll: poll,
            logger: logger,
            kernel: kernel
          ) do |message|
            expect(message[:id]).to eq(backlogged_message.id)
            expect(message[:messageable_type]).to eq(backlogged_message.messageable_type)
            expect(message[:messageable_id]).to eq(backlogged_message.messageable_id)
            expect(message[:status]).to eq(Models::Message::Status::PUBLISHING)

            Message.stop_publishing
          end

          expect(Models::Message.count).to eq(0)
        end
      end

      context 'when an error is raised in the block' do
        context 'when a standard error is raised' do
          let(:standard_error) { StandardError.new('some error') }

          before do
            Message.publish(
              queue: queue,
              threads: threads,
              poll: poll,
              logger: logger,
              kernel: kernel
            ) do |message|
              Message.stop_publishing

              raise standard_error
            end
          end

          it 'sets message to failed' do
            backlogged_message.reload

            expect(backlogged_message.status).to eq(Models::Message::Status::FAILED)

            expect(backlogged_message.exceptions.count).to eq(1)
            expect(backlogged_message.exceptions[0].class_name).to eq(standard_error.class.name)
            expect(backlogged_message.exceptions[0].message_text).to eq(standard_error.message)
            expect(backlogged_message.exceptions[0].created_at).not_to be_nil

            expect(backlogged_message.exceptions[0].frames.count).to eq(4)
            expect(backlogged_message.exceptions[0].frames[0].index).to eq(0)
            expect(backlogged_message.exceptions[0].frames[0].text).to include(
              "outboxer/message/publish_spec.rb:53:in `block (6 levels) in <module:Outboxer>'")
          end

          it 'logs errors' do
            expect(logger).to have_received(:error).with(
              a_string_matching(/^StandardError: some error/)
            ).once

            expect(logger).to have_received(:error).with(
              a_string_matching("Failed to publish message #{backlogged_message.id} for " \
                "#{backlogged_message[:messageable_type]}::#{backlogged_message[:messageable_id]}")
            ).once
          end
        end

        context 'when a critical error is raised' do
          let(:no_memory_error) { NoMemoryError.new }

          before do
            Message.publish(
              queue: queue,
              threads: threads,
              poll: poll,
              logger: logger,
              kernel: kernel
            ) do |queued_message|
              Message.stop_publishing

              raise no_memory_error
            end
          end

          it 'sets message to failed' do
            backlogged_message.reload

            expect(backlogged_message.status).to eq(Models::Message::Status::FAILED)

            expect(backlogged_message.exceptions.count).to eq(1)
            expect(backlogged_message.exceptions[0].class_name).to eq(no_memory_error.class.name)
            expect(backlogged_message.exceptions[0].message_text).to eq(no_memory_error.message)
            expect(backlogged_message.exceptions[0].created_at).not_to be_nil

            expect(backlogged_message.exceptions[0].frames.count).to eq(4)
            expect(backlogged_message.exceptions[0].frames[0].index).to eq(0)
            expect(backlogged_message.exceptions[0].frames[0].text).to match(
              /outboxer\/message\/publish_spec.rb:\d+:in `block \(6 levels\) in <module:Outboxer>'/)
          end

          it 'logs errors' do
            expect(logger).to have_received(:error).with(
              a_string_matching("Failed to publish message #{backlogged_message.id} for " \
                "#{backlogged_message[:messageable_type]}::#{backlogged_message[:messageable_id]}")
            ).once

            expect(logger).to have_received(:fatal).with(
              a_string_matching("#{no_memory_error.class.to_s}: #{no_memory_error.message}")
            ).once
          end
        end
      end
    end
  end
end
