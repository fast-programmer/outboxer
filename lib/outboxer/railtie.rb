require 'outboxer'
require 'rails'

module Outboxer
  class Railtie < Rails::Railtie
    railtie_name :outboxer

    generators do
      require_relative '../../generators/schema_generator'
      require_relative '../../generators/sidekiq_publisher_generator'
    end
  end
end
