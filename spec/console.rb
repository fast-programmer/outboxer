#!/usr/bin/env ruby

require 'bundler/setup'
env = ENV['OUTBOXER_ENV'] || 'development'

require 'active_record'
require 'pry-byebug'

require './lib/outboxer'

db_config_path = File.expand_path('spec/config/database.yml', Dir.pwd)
db_config = YAML.load_file(db_config_path)[env]

Outboxer::Publisher.connect!(db_config: db_config)

binding.pry

puts 'script finished'
