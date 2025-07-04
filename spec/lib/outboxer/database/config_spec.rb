require "rails_helper"

module Outboxer
  RSpec.describe Database do
    describe ".config" do
      context "when database_override.yml file exists" do
        let(:tmp_dir) { Dir.mktmpdir }
        let(:tmp_path) { File.join(tmp_dir, "database_override.yml") }

        before do
          ENV["DB_NAME"] = "override_db"

          File.write(tmp_path, <<~YAML)
            development:
              adapter: postgresql
              database: dev_db
              pool: 1
            test:
              adapter: postgresql
              database: <%= ENV["DB_NAME"] %>
              pool: 1
          YAML
        end

        after do
          FileUtils.rm_f tmp_path
          Dir.rmdir tmp_dir

          ENV.delete("DB_NAME")
        end

        it "returns correct config" do
          config = Database.config(environment: :test, pool: 3, path: tmp_path)

          expect(config).to include(
            adapter: "postgresql",
            database: "override_db",
            pool: 3)
        end
      end

      context "when the database_override.yml file does not exist" do
        let(:tmp_dir) { Dir.mktmpdir }

        after do
          Dir.rmdir tmp_dir
        end

        it "returns an empty hash" do
          missing_path = File.join(tmp_dir, "missing_database_override.yml")
          config = Database.config(environment: :test, pool: 2, path: missing_path)

          expect(config).to eq({})
        end
      end

      context "when no path is specified" do
        it "uses the default path" do
          config = Database.config(environment: :development, pool: 3)

          expect(config).to include(
            adapter: a_string_matching(/postgresql|mysql2/),
            encoding: "utf8",
            host: a_string_matching(/localhost|127\.0\.0\.1/),
            username: "outboxer_developer",
            password: "outboxer_password",
            database: "outboxer_development",
            pool: 3
          )
        end
      end
    end
  end
end
