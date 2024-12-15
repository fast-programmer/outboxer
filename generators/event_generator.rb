module Outboxer
  class EventGenerator < Rails::Generators::Base
    include Rails::Generators::Migration

    source_root File.expand_path('../', __dir__)

    def self.next_migration_number(dirname)
      next_number = Time.now.utc.strftime("%Y%m%d%H%M%S").to_i

      next_number += 1 while Dir.glob("#{dirname}/#{next_number}*").any?

      next_number.to_s
    end

    def copy_migrations
      migration_template(
        "db/migrate/create_events.rb",
        "db/migrate/create_events.rb")
    end

    def copy_model
      copy_file(
        "app/models/event.rb",
        "app/models/event.rb")
    end
  end
end
