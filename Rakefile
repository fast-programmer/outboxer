require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "pry"
require "rubocop/rake_task"

RuboCop::RakeTask.new

# task default: %i[spec rubocop]
task default: %i[spec]

load "lib/tasks/gem.rake"
