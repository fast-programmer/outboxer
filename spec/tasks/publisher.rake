require 'bundler/setup'
Bundler.require(:default, ENV.fetch('RAILS_ENV'))

namespace :outboxer do
  namespace :publisher do
    task :publish do
      command = "generators/outboxer/templates/bin/outboxer_publisher " \
        "--concurrency=5 "\
        "--poll=1 " \
        "--redis_url=redis://localhost:6379/0 " \
        "--db_config=../../../../config/database.yml"

      system command
    end
  end
end

# generators/outboxer/templates/bin/outboxer_publisher.rb --db_config=spec/config/database.yml
# bin/outboxer_publisher # --db_config=config/database.yml
