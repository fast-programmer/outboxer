require "spec_helper"

require "stringio"

module Outboxer
  RSpec.describe Logger do
    let(:output) { StringIO.new }
    let(:level) { "info" }
    let(:logger) { Logger.new(output, level: Logger.const_get(level.upcase)) }

    describe "logging" do
      it "logs messages with correct format" do
        message = "test message"
        logger.info { message }

        log_output = output.string
        log_lines = log_output.strip.split("\n")

        log_lines.each do |line|
          expect(line.length).to be <= 100
          expect(line).to match(
            /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}.\d{3}Z pid=\d+ tid=\w+ INFO: #{message}\n?/)
        end
      end
    end
  end
end
