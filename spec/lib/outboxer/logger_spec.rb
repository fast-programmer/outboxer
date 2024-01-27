require 'spec_helper'

require 'stringio'

module Outboxer
  RSpec.describe Logger do
    let(:output) { StringIO.new }
    let(:logger) { Logger.new(output) }

    describe 'logging' do
      it 'logs messages with correct format' do
        datetime = Time.now.strftime("%Y-%m-%d %H:%M:%S")
        severity = 'INFO'
        progname = 'test_program'
        message = 'test message'

        logger.info(progname) { message }

        log_output = output.string
        expect(log_output).to include(datetime)
        expect(log_output).to include(severity)
        expect(log_output).to include(progname)
        expect(log_output).to include(message)
      end

      it 'assigns colors to threads' do
        threads = []
        messages = []

        5.times do |i|
          threads << Thread.new do
            logger.info("Thread #{i}") { "Message #{i}" }
            messages << output.string
          end
        end

        threads.each(&:join)

        # Check if color codes are present and different for each thread
        colors = messages.map { |msg| msg[/\e\[\d+m/] }.uniq
        expect(colors.size).to be <= 5
        expect(colors.all? { |color| Outboxer::Logger::COLORS.include?(color) }).to be true
      end
    end
  end
end
