require 'spec_helper'
require_relative '../../../lib/outboxer/config'

module Outboxer
  RSpec.describe Config do
    describe '.load' do
      let(:config_content) do
        <<-YAML
          default: &default
            buffer: <%= ENV['OUTBOXER_BUFFER'] || 100 %>
            concurrency: <%= ENV['OUTBOXER_CONCURRENCY'] || 1 %>
            tick: <%= ENV['OUTBOXER_TICK'] || 0.1 %>
            poll: <%= ENV['OUTBOXER_POLL'] || 5.0 %>
            heartbeat: <%= ENV['OUTBOXER_HEARTBEAT'] || 5.0 %>

          development:
            <<: *default
            environment: development

          test:
            <<: *default
            environment: test
        YAML
      end

      before do
        allow(File).to receive(:read).and_return(config_content)
        allow(ENV).to receive(:[]).and_call_original  # Allow other ENV variables to work as expected
      end

      context 'when no environment variables are set' do
        it 'loads default values for development environment' do
          expect(Config.load(file: 'dummy.yml', environment: 'development')).to eq({
            "buffer" => 100,
            "concurrency" => 5,
            "tick" => 0.1,
            "poll" => 5.0,
            "heartbeat" => 5.0,
            "environment" => "development"
          })
        end

        it 'loads overridden values for test environment' do
          expect(Config.load(file: 'dummy.yml', environment: 'test')).to eq({
            "buffer" => 150,
            "concurrency" => 8,
            "tick" => 0.1,
            "poll" => 5.0,
            "heartbeat" => 5.0,
            "environment" => "test"
          })
        end
      end

      context 'when environment variables are set' do
        before do
          allow(ENV).to receive(:[]).with('OUTBOXER_BUFFER').and_return('120')
          allow(ENV).to receive(:[]).with('OUTBOXER_CONCURRENCY').and_return('6')
        end

        it 'overrides configuration with environment variables for development' do
          expect(Config.load(file: 'dummy.yml', environment: 'development')).to eq({
            "buffer" => 120,
            "concurrency" => 6,
            "tick" => 0.1,
            "poll" => 5.0,
            "heartbeat" => 5.0,
            "environment" => "development"
          })
        end

        it 'uses specific environment variables for test' do
          expect(Config.load(file: 'dummy.yml', environment: 'test')).to eq({
            "buffer" => 120,
            "concurrency" => 6,
            "tick" => 0.1,
            "poll" => 5.0,
            "heartbeat" => 5.0,
            "environment" => "test"
          })
        end
      end
    end
  end
end
