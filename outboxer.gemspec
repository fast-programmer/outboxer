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

  spec.add_dependency "activerecord", "~> 7.0"

  spec.add_development_dependency 'pry-byebug', '3.10'
  spec.add_development_dependency 'activerecord', '~> 7.0'
  spec.add_development_dependency 'database_cleaner', '~> 2.0', '>= 2.0.2'
  spec.add_development_dependency 'simplecov', '~> 0.22.0'
end
# rubocop:enable Layout/LineLength
