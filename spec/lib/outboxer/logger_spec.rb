require "rails_helper"
require "stringio"

module Outboxer
  RSpec.describe Logger do
    let(:output) { StringIO.new }
    let(:level) { "info" }
    let(:logger) { Logger.new(output, level: Logger.const_get(level.upcase)) }

    describe "logging" do
      context "thread name not set" do
        it "logs messages with generated tid" do
          Thread.current["outboxer_tid"] = nil
          Thread.current.name = nil

          message = "test message"
          logger.info { message }

          log_output = output.string
          log_lines = log_output.strip.split("\n")

          log_lines.each do |line|
            expect(line.length).to be <= 100
            expect(line).to match(
              /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}.\d{3}Z pid=\d+ tid=\w+ INFO: #{message}\n?/
            )
          end
        end
      end

      context "thread name set" do
        it "logs messages with thread name tid" do
          Thread.current["outboxer_tid"] = nil
          Thread.current.name = "blah"

          message = "test message"
          logger.info { message }

          log_output = output.string
          log_lines = log_output.strip.split("\n")

          log_lines.each do |line|
            expect(line.length).to be <= 100
            expect(line).to match(
              /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}.\d{3}Z pid=\d+ tid=\w+ INFO: #{message}\n?/
            )
          end
        end
      end
    end
  end
end
