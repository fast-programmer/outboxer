module Outboxer
  class InstallCloudwatchMetricsGenerator < Rails::Generators::Base
    source_root File.expand_path("../", __dir__)

    def copy_bin_file
      template "bin/outboxer_cloudwatch_metrics", "bin/outboxer_cloudwatch_metrics"
      run "chmod +x bin/outboxer_cloudwatch_metrics"
    end

    def print_instructions
      say <<~MSG

        To complete setup:

          1. Add to Gemfile:
               gem "aws-sdk-cloudwatch"

          2. Run:
               bundle install

          3. Start:
               bin/outboxer_cloudwatch_metrics

      MSG
    end
  end
end

# bundle exec rails g outboxer:install_cloudwatch_metrics
# bin/outboxer_cloudwatch_metrics
