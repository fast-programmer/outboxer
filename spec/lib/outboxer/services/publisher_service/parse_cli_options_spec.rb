require "rails_helper"

module Outboxer
  RSpec.describe PublisherService do
    describe ".parse_cli_options" do
      context "when no options are passed" do
        let(:argv) { [] }

        it "parses correctly" do
          expect(PublisherService.parse_cli_options(argv)).to eq({})
        end
      end

      context "when parsing the concurrency option" do
        let(:argv) { ["-c", "5"] }

        it "parses correctly" do
          expect(PublisherService.parse_cli_options(argv)).to eq({ concurrency: 5 })
        end
      end

      context "when parsing the environment option" do
        let(:argv) { ["-e", "staging"] }

        it "parses correctly" do
          expect(PublisherService.parse_cli_options(argv)).to eq({ environment: "staging" })
        end
      end

      context "when parsing the buffer limit option" do
        let(:argv) { ["-b", "100"] }

        it "parses correctly" do
          expect(PublisherService.parse_cli_options(argv)).to eq({ buffer: 100 })
        end
      end

      context "when parsing the poll interval option" do
        let(:argv) { ["-p", "30"] }

        it "parses correctly" do
          expect(PublisherService.parse_cli_options(argv)).to eq({ poll: 30 })
        end
      end

      context "when parsing the config file path option" do
        let(:argv) { ["-C", "config/path.yml"] }

        it "parses correctly" do
          expect(PublisherService.parse_cli_options(argv)).to eq({ config: "config/path.yml" })
        end
      end

      context "when parsing the log level option" do
        let(:argv) { ["-l", "0"] }

        it "parses correctly" do
          expect(PublisherService.parse_cli_options(argv)).to eq({ log_level: 0 })
        end
      end

      context "when the version option is used" do
        let(:argv) { ["-V"] }

        it "prints version and exits" do
          expect { PublisherService.parse_cli_options(argv) }
            .to output(/Outboxer version/).to_stdout.and raise_error(SystemExit)
        end
      end

      context "when the help option is used" do
        let(:argv) { ["-h"] }

        it "prints help and exits" do
          expect do
            PublisherService.parse_cli_options(argv)
          end.to output(
            /Usage: outboxer_publisher \[options\]/).to_stdout.and raise_error(SystemExit)
        end
      end
    end
  end
end
