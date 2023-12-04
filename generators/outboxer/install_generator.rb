module Outboxer
  class InstallGenerator < Rails::Generators::Base
    include Rails::Generators::Migration

    source_root File.expand_path("templates", __dir__)

    def self.next_migration_number(dirname)
      next_number = Time.now.utc.strftime("%Y%m%d%H%M%S").to_i

      next_number += 1 while Dir.glob("#{dirname}/#{next_number}*").any?

      next_number.to_s
    end

    def copy_bin_file
      template "bin/outboxer_publisher.rb", "bin/outboxer_publisher"
      run "chmod +x bin/outboxer_publisher"
    end

    def copy_migrations
      migration_template(
        "migrations/create_outboxer_messages.rb",
        "db/migrate/create_outboxer_messages.rb")

      migration_template(
        "migrations/create_outboxer_exceptions.rb",
        "db/migrate/create_outboxer_exceptions.rb")
    end
  end
end
