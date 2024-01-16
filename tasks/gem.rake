require "rake/packagetask"

namespace :gem do
  desc "Bump version number"
  task :bump, [:type] do |_t, args|
    args.with_defaults(type: "patch")

    unless %w[major minor patch].include?(args[:type])
      raise "Invalid version type - choose from major/minor/patch"
    end

    version_file = File.expand_path("../../lib/outboxer/version.rb", __dir__)
    version = ""
    File.open(version_file, "r") do |file|
      version = file.read.match(/VERSION = "(.*)"/)[1]
    end

    version_parts = version.split(".").map(&:to_i)
    case args[:type]
    when "major"
      version_parts[0] += 1
      version_parts[1] = 0
      version_parts[2] = 0
    when "minor"
      version_parts[1] += 1
      version_parts[2] = 0
    when "patch"
      version_parts[2] += 1
    end

    new_version = version_parts.join(".")
    File.write(version_file, "module Outboxer\n  VERSION = \"#{new_version}\".freeze\nend\n")

    puts "Gem version bumped to #{new_version}"
  end

  desc "Build the gem"
  task :build do
    Outboxer.send(:remove_const, :VERSION) if Outboxer.const_defined?(:VERSION)
    load "lib/outboxer/version.rb"
    sh "gem build outboxer.gemspec"

    puts "Gem built successfully."
  end

  desc "Push the gem to RubyGems"
  task :push do
    Outboxer.send(:remove_const, :VERSION) if Outboxer.const_defined?(:VERSION)
    load "lib/outboxer/version.rb"
    version = Outboxer::VERSION
    sh "gem push outboxer-#{version}.gem"

    puts "Gem pushed to RubyGems."
  end

  desc "Bump, build and push the gem to RubyGems"
  task release: %i[bump build push]
end
