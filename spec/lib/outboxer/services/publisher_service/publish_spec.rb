# rubocop:disable Layout/LineLength
require "rails_helper"

module Outboxer
  RSpec.describe PublisherService do
    describe ".publish" do
      let(:environment) { "test" }
      let(:buffer) { 1 }
      let(:poll) { 1 }
      let(:tick) { 0.1 }
      let(:logger) { instance_double(Logger, debug: true, error: true, fatal: true, info: true) }
      let(:database) { class_double(DatabaseService, config: nil, connect: nil, disconnect: nil) }
      let(:kernel) { class_double(Kernel, sleep: nil) }

      before do
        allow(logger).to receive(:level=)
      end

      let!(:queued_message) { create(:outboxer_message, :queued) }

      context "when TTIN signal sent" do
        it "dumps stack trace" do
          publish_thread = Thread.new do
            Outboxer::PublisherService.publish(
              environment: environment,
              buffer: buffer,
              poll: poll,
              tick: tick,
              database: database,
              logger: logger, kernel: kernel) do |_message|
              ::Process.kill("TTIN", ::Process.pid)
            end
          end

          sleep 1

          ::Process.kill("TERM", ::Process.pid)

          publish_thread.join

          expect(logger)
            .to have_received(:info)
            .with(a_string_including("backtrace"))
            .at_least(:once)
        end
      end

      context "when stopped and resumed during message publishing" do
        it "stops and resumes the publishing process correctly" do
          publish_thread = Thread.new do
            Outboxer::PublisherService.publish(
              environment: environment,
              buffer: buffer,
              poll: poll,
              tick: tick,
              logger: logger,
              database: database,
              kernel: kernel) do |_message|
              ::Process.kill("TSTP", ::Process.pid)
            end
          end
          sleep 2

          ::Process.kill("CONT", ::Process.pid)
          sleep 1

          ::Process.kill("TERM", ::Process.pid)

          publish_thread.join
        end
      end

      context "when message published successfully" do
        it "sets the message to published" do
          PublisherService.publish(
            environment: environment,
            buffer: buffer,
            poll: poll,
            tick: tick,
            logger: logger,
            database: database,
            kernel: kernel) do |message|
            expect(message[:id]).to eq(queued_message.id)
            expect(message[:messageable_type]).to eq(queued_message.messageable_type)
            expect(message[:messageable_id]).to eq(queued_message.messageable_id)
            expect(message[:status]).to eq(Message::Status::PUBLISHING)

            ::Process.kill("TERM", ::Process.pid)
          end

          expect(Message.published.count).to eq(1)
        end
      end

      context "when an error is raised in the block" do
        context "when a standard error is raised" do
          let(:standard_error) { StandardError.new("some error") }

          before do
            PublisherService.publish(
              environment: environment,
              buffer: buffer,
              poll: poll,
              tick: tick,
              logger: logger,
              database: database,
              kernel: kernel) do |_message|
              ::Process.kill("TERM", ::Process.pid)

              raise standard_error
            end
          end

          it "sets message to failed" do
            queued_message.reload

            expect(queued_message.status).to eq(Message::Status::FAILED)
            expect(queued_message.exceptions.count).to eq(1)
            expect(queued_message.exceptions[0].class_name).to eq(standard_error.class.name)
            expect(queued_message.exceptions[0].message_text).to eq(standard_error.message)
            expect(queued_message.exceptions[0].created_at).not_to be_nil

            expect(queued_message.exceptions[0].frames[0].index).to eq(0)

            expect(queued_message.exceptions[0].frames[0].text).to match(
              /outboxer\/services\/publisher_service\/publish_spec.rb:\d+:in `block \(6 levels\) in <module:Outboxer>'/)
          end

          it "logs errors" do
            expect(logger).to have_received(:error).with(
              a_string_matching(/^StandardError: some error/)).once

            expect(logger).to have_received(:debug).with(
              a_string_matching("failed to publish message id=#{queued_message.id} " \
                "messageable=#{queued_message[:messageable_type]}::#{queued_message[:messageable_id]}")).once
          end
        end

        context "when a critical error is raised" do
          let(:no_memory_error) { NoMemoryError.new }

          before do
            PublisherService.publish(
              environment: environment,
              buffer: buffer,
              poll: poll,
              tick: tick,
              logger: logger,
              database: database,
              kernel: kernel) do |_buffered_message|
              raise no_memory_error
            end
          end

          it "sets message to failed" do
            queued_message.reload

            expect(queued_message.status).to eq(Message::Status::FAILED)
            expect(queued_message.exceptions.count).to eq(1)
            expect(queued_message.exceptions[0].class_name).to eq(no_memory_error.class.name)
            expect(queued_message.exceptions[0].message_text).to eq(no_memory_error.message)
            expect(queued_message.exceptions[0].created_at).not_to be_nil

            expect(queued_message.exceptions[0].frames[0].index).to eq(0)
            expect(queued_message.exceptions[0].frames[0].text).to match(
              /outboxer\/services\/publisher_service\/publish_spec.rb:\d+:in `block \(6 levels\) in <module:Outboxer>'/)
          end

          it "logs errors" do
            expect(logger).to have_received(:debug).with(
              a_string_matching("failed to publish message id=#{queued_message.id} " \
                "messageable=#{queued_message[:messageable_type]}::#{queued_message[:messageable_id]}")).once

            expect(logger).to have_received(:fatal).with(
              a_string_matching("#{no_memory_error.class}: #{no_memory_error.message}")).once
          end
        end

        context "when MessagesService.buffer raises a StandardError" do
          it "logs the error and continues processing" do
            call_count = 0

            allow(MessagesService).to receive(:buffer) do
              call_count += 1

              case call_count
              when 1
                raise StandardError, "queue error"
              else
                ::Process.kill("TERM", ::Process.pid)

                []
              end
            end

            expect(logger).to receive(:error).with(include("StandardError: queue error")).once

            PublisherService.publish(
              environment: environment,
              buffer: buffer,
              poll: poll,
              tick: tick,
              logger: logger,
              database: database,
              kernel: kernel)
          end
        end

        context "when MessagesService.buffer raises an Exception" do
          it "logs the exception and shuts down" do
            allow(MessagesService).to receive(:buffer)
              .and_raise(NoMemoryError, "failed to allocate memory")

            expect(logger).to receive(:fatal)
              .with(include("NoMemoryError: failed to allocate memory"))
              .once

            PublisherService.publish(
              environment: environment,
              buffer: buffer,
              poll: poll,
              tick: tick,
              logger: logger,
              database: database,
              kernel: kernel)
          end
        end
      end
    end
  end
end
# rubocop:enable Layout/LineLength
