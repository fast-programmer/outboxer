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
        "db/migrate/create_outboxer_settings.rb",
        "db/migrate/create_outboxer_settings.rb")

      migration_template(
        "db/migrate/create_outboxer_messages.rb",
        "db/migrate/create_outboxer_messages.rb")

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

      migration_template(
        "db/migrate/create_events.rb",
        "db/migrate/create_events.rb")
    end

    def copy_models
      copy_file(
        "app/models/event.rb",
        "app/models/event.rb")

      copy_file(
        "app/models/outboxer_integration/test.rb",
        "app/models/outboxer_integration/test.rb")

      copy_file(
        "app/models/outboxer_integration/test/started_event.rb",
        "app/models/outboxer_integration/test/started_event.rb")

      copy_file(
        "app/models/outboxer_integration/test/completed_event.rb",
        "app/models/outboxer_integration/test/completed_event.rb")

      copy_file(
        "app/services/outboxer_integration/test_service.rb",
        "app/services/outboxer_integration/test_service.rb")
    end

    def copy_bin_file
      template "bin/outboxer_publisher", "bin/outboxer_publisher"
      run "chmod +x bin/outboxer_publisher"
    end

    def copy_jobs
      copy_file(
        "app/jobs/outboxer_integration/message/publish_job.rb",
        "app/jobs/outboxer_integration/message/publish_job.rb")

      copy_file(
        "app/jobs/outboxer_integration/test_started_job.rb",
        "app/jobs/outboxer_integration/test_started_job.rb")

      copy_file(
        "app/jobs/outboxer_integration/complete_test_job.rb",
        "app/jobs/outboxer_integration/complete_test_job.rb")
    end

    def copy_specs
      copy_file(
        "spec/bin/outboxer_publisher_spec.rb",
        "spec/bin/outboxer_publisher_spec.rb")
    end
  end
end
