require "rails_helper"

module Outboxer
  RSpec.describe Publisher do
    describe ".parse_cli_options" do
      context "when no options are passed" do
        let(:argv) { [] }

        it "returns empty hash" do
          expect(Publisher.parse_cli_options(argv)).to eq({})
        end
      end

      context "when options are passed" do
        context "when parsing the environment option" do
          it "parses the environment flag" do
            expect(Publisher.parse_cli_options(["--environment", "staging"]))
              .to eq({ environment: "staging" })
          end
        end

        it "parses the batch size flag" do
          expect(Publisher.parse_cli_options(["--batch-size", "100"])).to eq({ batch_size: 100 })
        end

        it "parses the buffer size flag" do
          expect(Publisher.parse_cli_options(["--buffer-size", "100"])).to eq({ buffer_size: 100 })
        end

        it "parses buffering concurrency flag" do
          expect(Publisher.parse_cli_options(["--buffering-concurrency", "8"]))
            .to eq({ buffering_concurrency: 8 })
        end

        it "parses publishing concurrency flag" do
          expect(Publisher.parse_cli_options(["--publishing-concurrency", "7"]))
            .to eq({ publishing_concurrency: 7 })
        end

        it "parses the tick interval flag" do
          expect(
            Publisher.parse_cli_options(["--tick-interval", "0.5"])
          ).to eq({ tick_interval: 0.5 })
        end

        it "parses the poll interval flag" do
          expect(
            Publisher.parse_cli_options(["--poll-interval", "30"])
          ).to eq({ poll_interval: 30 })
        end

        it "parses the heartbeat interval flag" do
          expect(
            Publisher.parse_cli_options(["--heartbeat-interval", "10"])
          ).to eq({ heartbeat_interval: 10 })
        end

        it "parses the sweep interval flag" do
          expect(
            Publisher.parse_cli_options(["--sweep-interval", "10"])
          ).to eq({ sweep_interval: 10 })
        end

        it "parses the sweep retention flag" do
          expect(
            Publisher.parse_cli_options(["--sweep-retention", "10"])
          ).to eq({ sweep_retention: 10 })
        end

        it "parses the sweep batch size flag" do
          expect(
            Publisher.parse_cli_options(["--sweep-batch_size", "10"])
          ).to eq({ sweep_batch_size: 10 })
        end

        it "parses the config file flag" do
          expect(
            Publisher.parse_cli_options(["--config", "config/path.yml"])
          ).to eq({ config: "config/path.yml" })
        end

        it "parses the log level flag" do
          expect(Publisher.parse_cli_options(["--log-level", "0"])).to eq({ log_level: 0 })
        end

        it "parses the version flag, prints version and exits" do
          expect { Publisher.parse_cli_options(["--version"]) }
            .to output(/Outboxer version/).to_stdout.and raise_error(SystemExit)
        end

        it "parses the help flag, prints help and exits" do
          expect do
            Publisher.parse_cli_options(["--help"])
          end.to output(
            /Usage: outboxer_publisher \[options\]/).to_stdout.and raise_error(SystemExit)
        end
      end
    end
  end
end
