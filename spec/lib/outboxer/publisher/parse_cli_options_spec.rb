require "rails_helper"

module Outboxer
  RSpec.describe Publisher do
    describe ".parse_cli_options" do
      context "when no options are passed" do
        let(:argv) { [] }

        it "parses correctly" do
          expect(Publisher.parse_cli_options(argv)).to eq({})
        end
      end

      context "when parsing the concurrency option" do
        it "parses short and long flags" do
          expect(Publisher.parse_cli_options(["-c", "5"])).to eq({ concurrency: 5 })
          expect(Publisher.parse_cli_options(["--concurrency", "5"])).to eq({ concurrency: 5 })
        end
      end

      context "when parsing the environment option" do
        it "parses short and long flags" do
          expect(Publisher.parse_cli_options(["-e", "staging"])).to eq({ environment: "staging" })
          expect(Publisher.parse_cli_options(["--environment", "staging"])).to eq({ environment: "staging" })
        end
      end

      context "when parsing the buffer size option" do
        it "parses short and long flags" do
          expect(Publisher.parse_cli_options(["-b", "100"])).to eq({ buffer_size: 100 })
          expect(Publisher.parse_cli_options(["--buffer-size", "100"])).to eq({ buffer_size: 100 })
        end
      end

      context "when parsing the tick interval option" do
        it "parses short and long flags" do
          expect(Publisher.parse_cli_options(["-t", "0.5"])).to eq({ tick_interval: 0.5 })
          expect(Publisher.parse_cli_options(["--tick-interval", "0.5"])).to eq({ tick_interval: 0.5 })
        end
      end

      context "when parsing the poll interval option" do
        it "parses short and long flags" do
          expect(Publisher.parse_cli_options(["-p", "30"])).to eq({ poll_interval: 30 })
          expect(Publisher.parse_cli_options(["--poll-interval", "30"])).to eq({ poll_interval: 30 })
        end
      end

      context "when parsing the heartbeat interval option" do
        it "parses short and long flags" do
          expect(Publisher.parse_cli_options(["-a", "10"])).to eq({ heartbeat_interval: 10 })
          expect(Publisher.parse_cli_options(["--heartbeat-interval", "10"])).to eq({ heartbeat_interval: 10 })
        end
      end

      context "when parsing the config file path option" do
        it "parses short and long flags" do
          expect(Publisher.parse_cli_options(["-C", "config/path.yml"])).to eq({ config: "config/path.yml" })
          expect(Publisher.parse_cli_options(["--config", "config/path.yml"])).to eq({ config: "config/path.yml" })
        end
      end

      context "when parsing the log level option" do
        it "parses short and long flags" do
          expect(Publisher.parse_cli_options(["-l", "0"])).to eq({ log_level: 0 })
          expect(Publisher.parse_cli_options(["--log-level", "0"])).to eq({ log_level: 0 })
        end
      end

      context "when the version option is used" do
        let(:argv) { ["-V"] }

        it "prints version and exits" do
          expect { Publisher.parse_cli_options(argv) }
            .to output(/Outboxer version/).to_stdout.and raise_error(SystemExit)
        end
      end

      context "when the help option is used" do
        let(:argv) { ["-h"] }

        it "prints help and exits" do
          expect do
            Publisher.parse_cli_options(argv)
          end.to output(
            /Usage: outboxer_publisher \[options\]/).to_stdout.and raise_error(SystemExit)
        end
      end
    end
  end
end
