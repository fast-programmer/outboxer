module Outboxer
  class Railtie < Rails::Railtie
    railtie_name :outboxer

    generators do
      require_relative '../../generators/schema_generator'
      require_relative '../../generators/event_generator'
      require_relative '../../generators/sidekiq_publisher_generator'
      require_relative '../../generators/publisher_generator'
    end

    rake_tasks do
      namespace :outboxer do
        namespace :db do
          desc "Load outboxer's seed data"
          task seed: :environment do
            load File.expand_path('../../db/seeds.rb', __dir__)
          end
        end
      end
    end
  end
end
