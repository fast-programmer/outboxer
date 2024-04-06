module Outboxer
  class MessagePublisherGenerator < Rails::Generators::Base
    include Rails::Generators::Migration

    source_root File.expand_path('../', __dir__)
    def copy_bin_file
      template "bin/outboxer_message_publisher", "bin/outboxer_message_publisher"
      run "chmod +x bin/outboxer_message_publisher"
    end
  end
end
