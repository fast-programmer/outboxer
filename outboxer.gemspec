require_relative "lib/outboxer/version"

Gem::Specification.new do |spec|
  spec.name = "outboxer"
  spec.version = Outboxer::VERSION
  spec.authors = ["Adam Mikulasev"]
  spec.email = ["adam@fastprogrammer.co"]

  spec.summary = "Transactional outbox implementation for event driven Ruby on Rails applications that use SQL"
  spec.homepage = "https://github.com/fast-programmer/outboxer"
  spec.license       = "LGPL-3.0"
  spec.required_ruby_version = ">= 3.1.5"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/fast-programmer/outboxer"
  spec.metadata["documentation_uri"] = "https://rubydoc.info/github/fast-programmer/outboxer/master"
  spec.metadata["changelog_uri"] = "https://github.com/fast-programmer/outboxer/blob/master/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec_files = Dir.chdir(__dir__) do
    [
      'db/seeds.rb',
      'db/migrate/**/*',
      'generators/**/*',
      'LICENCE.txt',
      'lib/**/*',
      'README.md'
    ].flat_map { |path| Dir.glob(path) }
  end

  spec.files = spec_files

  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", "~> 7.0"
  spec.add_dependency "rack-flash3", "~> 1.0"
  spec.add_dependency "rackup", "~> 2.0"
  spec.add_dependency "sinatra", "~> 4.0"
  spec.add_dependency "sidekiq", "~> 7.0"

  spec.add_development_dependency "activerecord", "~> 7.0"
  spec.add_development_dependency "database_cleaner", "~> 2.0"
  spec.add_development_dependency "dotenv", "~> 3.0"
  spec.add_development_dependency "factory_bot", "~> 6.0"
  spec.add_development_dependency "foreman", "~> 0.0"
  spec.add_development_dependency "pry-byebug", "~> 3.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rerun", "~> 0.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rubocop", "~> 1.0"
  spec.add_development_dependency "simplecov", "~> 0.0"
  spec.add_development_dependency "yard", ">= 0.9.36", "< 1.0"
end
