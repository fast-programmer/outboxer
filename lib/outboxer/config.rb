require 'yaml'
require 'erb'

module Outboxer
  class Config
    def self.load(file:, environment:)
      yaml = ERB.new(File.read(file)).result
      config = YAML.safe_load(yaml, aliases: true)
      config[environment] || config
    end
  end
end
