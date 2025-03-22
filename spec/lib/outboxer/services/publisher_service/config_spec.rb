require "erb"
require "yaml"

module Outboxer
  RSpec.describe PublisherService do
    describe ".config" do
      let(:environment) { "test" }
      let(:config_path) { "spec/fixtures/config.yml" }
      let(:default_path) { "config/database.yml" }
      let(:file_content) {
        "---\ntest:\ndatabase: 'db_test'\nusername: 'user_test'\npassword: 'pass_test'\n"
      }

      before do
        allow(File).to receive(:read).and_call_original
        allow(File).to receive(:read).with(config_path).and_return(file_content)
        stub_const("PublisherService::DEFAULT_OPTIONS", config_path: default_path)
        allow(::Dir).to receive(:pwd).and_return("/fakepath")
      end

      it "parses db config from a file for the specified environment" do
        config = PublisherService.config(environment: 'development', path: 'spec/fixtures/config/outboxer.yml')
        expect(config).to eq({
          database: "db_test", username: "user_test", password: "pass_test"
        })
      end

      context "when no path is provided" do
        let(:file_content_default) {
          "---\ntest:\ndatabase: 'db_default'\nusername: 'user_default'\npassword: 'pass_default'\n"
        }

        before do
          allow(File).to receive(:read).with(default_path).and_return(file_content_default)
          allow(File).to receive(:expand_path)
            .with(default_path, "/fakepath")
            .and_return("/fakepath/#{default_path}")
        end

        it "uses the default configuration file path" do
          config = PublisherService.config(environment: environment)
          expect(config).to eq({
            database: "db_default", username: "user_default", password: "pass_default"
          })
        end
      end

      context "when file content contains ERB tags" do
        let(:file_content_with_erb) {
          "---\ntest:\ndatabase: <%= ENV['DATABASE_NAME'] %>\nusername: 'user_test'\npassword: 'pass_test'\n"
        }

        before do
          allow(File).to receive(:read).with(config_path).and_return(file_content_with_erb)
          allow(ENV).to receive(:[]).with("DATABASE_NAME").and_return("db_from_env")
        end

        it "evaluates ERB tags within the file" do
          config = PublisherService.config(environment: environment, path: config_path)
          expect(config).to eq({
            database: "db_from_env", username: "user_test", password: "pass_test"
          })
        end
      end
    end
  end
end
