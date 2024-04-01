require 'spec_helper'

module Outboxer
  RSpec.describe Message do
    describe '.publish!' do
      let(:queue) { 1 }
      let(:threads) { 1 }
      let(:poll) { 1 }
      let(:logger) { instance_double(Logger, debug: true, error: true, fatal: true, info: true) }
      let(:kernel) { class_double(Kernel, sleep: nil) }

      before do
        allow(logger).to receive(:level=)
      end

      let!(:message) { create(:outboxer_message, :backlogged) }

      context 'when message published successfully' do
        before do
          Message.publish!(
            queue: queue,
            threads: threads,
            poll: poll,
            logger: logger,
            kernel: kernel
          ) do |queued_message|
            expect(queued_message.messageable_type).to eq('Event')
            expect(queued_message.messageable_id).to eq('1')
            expect(queued_message.status).to eq(Models::Message::Status::QUEUED)

            Message.stop_publishing!
          end
        end

        it 'deletes existing message' do
          Message.stop_publishing!

          expect(Models::Message.count).to eq(0)
        end
      end

      context 'when an error is raised in the block' do
        context 'when a standard error is raised' do
          let(:standard_error) { StandardError.new('some error') }

          before do
            Message.publish!(
              queue: queue,
              threads: threads,
              poll: poll,
              logger: logger,
              kernel: kernel
            ) do |queued_message|
              Process.kill('SIGINT', Process.pid)
              # Message.stop_publishing!

              raise standard_error
            end
          end

          it 'logs errors' do
            expect(logger).to have_received(:error).with(
              "Message publishing failed { id: #{message.id}, error: #{standard_error.message} }").once

            expect(logger).to have_received(:error).with(
              "#{standard_error.class.to_s}: #{standard_error.message}").once
          end
        end

        context 'when a critical error is raised' do
          let(:no_memory_error) { NoMemoryError.new }

          before do
            Message.publish!(
              queue: queue,
              threads: threads,
              poll: poll,
              logger: logger,
              kernel: kernel
            ) do |queued_message|
              # Process.kill('SIGINT', Process.pid)

              raise no_memory_error
            end
          end

          it 'logs errors' do
            expect(logger).to have_received(:error).with(
              "Message publishing failed { id: #{message.id}, error: #{no_memory_error.message} }").once

            expect(logger).to have_received(:fatal)
              .with("#{no_memory_error.class.to_s}: #{no_memory_error.message}").once
          end
        end
      end
    end
  end
end
