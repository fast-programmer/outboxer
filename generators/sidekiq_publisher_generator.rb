module Outboxer
  class SidekiqPublisherGenerator < Rails::Generators::Base
    include Rails::Generators::Migration

    source_root File.expand_path('../', __dir__)
    def copy_bin_file
      template "bin/sidekiq_publisher", "bin/sidekiq_publisher"
      run "chmod +x bin/sidekiq_publisher"
    end
  end
end
