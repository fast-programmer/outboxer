module Outboxer
  class InstallGenerator < Rails::Generators::Base
    include Rails::Generators::Migration

    source_root File.expand_path("../", __dir__)

    def self.next_migration_number(dirname)
      next_number = Time.now.utc.strftime("%Y%m%d%H%M%S").to_i

      next_number += 1 while Dir.glob("#{dirname}/#{next_number}*").any?

      next_number.to_s
    end

    def copy_migrations
      migration_template(
        "db/migrate/create_outboxer_messages.rb",
        "db/migrate/create_outboxer_messages.rb")

      migration_template(
        "db/migrate/create_outboxer_counters.rb",
        "db/migrate/create_outboxer_counters.rb")

      migration_template(
        "db/migrate/create_outboxer_exceptions.rb",
        "db/migrate/create_outboxer_exceptions.rb")

      migration_template(
        "db/migrate/create_outboxer_frames.rb",
        "db/migrate/create_outboxer_frames.rb")

      migration_template(
        "db/migrate/create_outboxer_publishers.rb",
        "db/migrate/create_outboxer_publishers.rb")

      migration_template(
        "db/migrate/create_outboxer_signals.rb",
        "db/migrate/create_outboxer_signals.rb")
    end

    def copy_bin_file
      template "bin/outboxer_publisher", "bin/outboxer_publisher"
      run "chmod +x bin/outboxer_publisher"

      copy_file(
        "spec/bin/outboxer_publisher_spec.rb",
        "spec/bin/outboxer_publisher_spec.rb")
    end
  end
end
