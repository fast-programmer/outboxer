require 'spec_helper'

module Outboxer
  RSpec.describe OptionParser do
    describe '.parse' do
      it 'returns default options when no arguments are given' do
        args = []
        expected = {
          config_file: 'config/outboxer.yml',
          environment: 'development',
          buffer: nil,
          concurrency: nil,
          verbose: false
        }
        expect(OptionParser.parse(args)).to eq(expected)
      end

      it 'overrides the environment when specified' do
        args = ['-e', 'test']
        expected = {
          config_file: 'config/outboxer.yml',
          environment: 'test',
          buffer: 100,
          concurrency: 1,
          verbose: false
        }
        expect(described_class.parse(args)).to eq(expected)
      end

      it 'sets the verbose flag when specified' do
        args = ['-v']
        result = described_class.parse(args)
        expect(result[:verbose]).to be true
      end

      it 'overrides the config file path when specified' do
        args = ['-c', 'custom_config.yml']
        result = described_class.parse(args)
        expect(result[:config_file]).to eq('custom_config.yml')
      end

      it 'parses buffer and concurrency options correctly' do
        args = ['--buffer', '150', '--concurrency', '10']
        result = described_class.parse(args)
        expect(result[:buffer]).to eq(150)
        expect(result[:concurrency]).to eq(10)
      end

      it 'exits the program when version flag is used' do
        args = ['-V']
        expect { described_class.parse(args) }.to output("Outboxer version 1.0.0\n").to_stdout.and raise_error(SystemExit)
      end

      it 'exits the program and shows help when help flag is used' do
        args = ['-h']
        expect { described_class.parse(args) }.to output(/Usage: outboxer \[options\]/).to_stdout.and raise_error(SystemExit)
      end
    end
  end
end
