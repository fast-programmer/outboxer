module Outboxer
  class SidekiqPublisherGenerator < Rails::Generators::Base
    include Rails::Generators::Migration

    source_root File.expand_path('../', __dir__)
    def copy_bin_file
      template "bin/outboxer_sidekiq_publisher", "bin/outboxer_publisher"
      run "chmod +x bin/outboxer_publisher"
    end
  end
end
