require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "pry"
require "rubocop/rake_task"

RuboCop::RakeTask.new

task default: %i[spec rubocop]

load "lib/tasks/gem.rake"
