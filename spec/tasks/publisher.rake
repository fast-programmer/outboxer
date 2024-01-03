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


# bin/outboxer_publisher \
#   --messageable_type=Models::DomainEvent --worker=workers/domain_event_handler_worker.rb \
#   --messageable_type=Models::Log         --worker=workers/log_handler_worker.rb

# bin/outboxer_publisher \
#   --concurrency=5
#   --poll=1
#   --redis_url=redis://localhost:6379/0
#   --db_config_path=spec/config/database.yml
#   --messageable_type=Models::DomainEvent --worker=workers/domain_event_handler_worker.rb \
#   --messageable_type=Models::Log         --worker=workers/log_handler_worker.rb

1. run the install generator
2. migrate the database
3. include outboxable in your models
4. add a handler worker
5. run the publisher script

# bin/outboxer_publisher \
#   --concurrency=5
#   --poll=1
#   --redis_url=redis://localhost:6379/0
#   --db_config=spec/config/database.yml
#   --messageable_type=Models::DomainEvent --worker=workers/domain_event_handler_worker.rb \
#   --messageable_type=Models::Log         --worker=workers/log_handler_worker.rb


# ruby generators/outboxer/templates/bin/outboxer_publisher.rb \
#   --concurrency=5 \
#   --poll=1 \
#   --redis_url=redis://localhost:6379/0 \
#   --db_config=spec/config/database.yml \
#   --messageable_type=Models::DomainEvent --worker=workers/domain_event_handler_worker.rb \
#   --messageable_type=Models::Log         --worker=workers/log_handler_worker.rb
