# rubocop:disable Layout/LineLength
require_relative "lib/outboxer/version"

Gem::Specification.new do |spec|
  spec.name = "outboxer"
  spec.version = Outboxer::VERSION
  spec.authors = ["Adam Mikulasev"]
  spec.email = ["adam@fastprogrammer.co"]

  spec.summary = "Transactional outbox implementation for event driven Ruby on Rails applications that use SQL"
  spec.homepage = "https://github.com/fast-programmer/outboxer"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/fast-programmer/outboxer"
  spec.metadata["documentation_uri"] = "https://rubydoc.info/github/fast-programmer/outboxer/master"
  spec.metadata["changelog_uri"] = "https://github.com/fast-programmer/outboxer/blob/master/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", "~> 7.1", ">= 7.1.2"
  spec.add_dependency "rackup", "~> 2.1"
  spec.add_dependency "sinatra", "~> 4.0"
  spec.add_dependency 'kaminari', '~> 1.2'
  spec.add_dependency 'rack-flash3', '~> 1.0', '>= 1.0.5'

  spec.add_development_dependency 'dotenv', '>= 3.1.2'
  spec.add_development_dependency 'foreman', '~> 0.87.2'
  spec.add_development_dependency 'pry-byebug', '~> 3.10', '>= 3.10.1'
  spec.add_development_dependency 'activerecord', '~> 7.0'
  spec.add_development_dependency 'database_cleaner', '~> 2.0', '>= 2.0.2'
  spec.add_development_dependency 'sidekiq', '~> 7.2', '>= 7.2.1'
  spec.add_development_dependency 'simplecov', '~> 0.22.0'
  spec.add_development_dependency 'factory_bot', '~> 6.4', '>= 6.4.6'
  spec.add_development_dependency 'rerun', '~> 0.14.0'
  spec.add_development_dependency "yard", "~> 0.9.34"
  spec.add_development_dependency "rubocop", "~> 1.55"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec"
end
# rubocop:enable Layout/LineLength
