require "outboxer"
require "rails"

module Outboxer
  class Railtie < Rails::Railtie
    railtie_name :outboxer

    generators do
      require_relative "../../generators/outboxer/install_generator"
    end
  end
end
