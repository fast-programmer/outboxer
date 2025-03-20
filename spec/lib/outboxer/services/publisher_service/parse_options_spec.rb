require "rails_helper"

module Outboxer
  RSpec.describe PublisherService do
    describe ".parse_options" do
      context "when no options are passed" do
        let(:args) { [] }

        it "parses correctly" do
          expect(PublisherService.parse_options(args)).to eq({})
        end
      end

      context "when parsing the concurrency option" do
        let(:args) { ["-c", "5"] }

        it "parses correctly" do
          expect(PublisherService.parse_options(args)).to eq({ concurrency: 5 })
        end
      end

      context "when parsing the environment option" do
        let(:args) { ["-e", "staging"] }

        it "parses correctly" do
          expect(PublisherService.parse_options(args)).to eq({ environment: "staging" })
        end
      end

      context "when parsing the buffer limit option" do
        let(:args) { ["-b", "100"] }

        it "parses correctly" do
          expect(PublisherService.parse_options(args)).to eq({ buffer: 100 })
        end
      end

      context "when parsing the poll interval option" do
        let(:args) { ["-p", "30"] }

        it "parses correctly" do
          expect(PublisherService.parse_options(args)).to eq({ poll: 30 })
        end
      end

      context "when parsing the config file path option" do
        let(:args) { ["-C", "config/path.yml"] }

        it "parses correctly" do
          expect(PublisherService.parse_options(args)).to eq({ config: "config/path.yml" })
        end
      end

      context "when parsing the log level option" do
        let(:args) { ["-l", "debug"] }

        it "parses correctly" do
          expect(PublisherService.parse_options(args)).to eq({ log_level: "debug" })
        end
      end

      context "when the version option is used" do
        let(:args) { ["-V"] }

        it "prints version and exits" do
          expect { PublisherService.parse_options(args) }
            .to output(/Outboxer version/).to_stdout.and raise_error(SystemExit)
        end
      end

      context "when the help option is used" do
        let(:args) { ["-h"] }

        it "prints help and exits" do
          expect do
            PublisherService.parse_options(args)
          end.to output(/Usage: outboxer_publisher \[options\]/).to_stdout.and raise_error(SystemExit)
        end
      end
    end
  end
end
