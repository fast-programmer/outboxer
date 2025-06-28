#!/usr/bin/env bash
set -euo pipefail

: "${TARGET_RUBY_VERSION:?must be set}"
: "${TARGET_RAILS_VERSION:?must be set}"
: "${TARGET_DATABASE_ADAPTER:?must be set}"

app_dir="outboxer_app_$(date +"%Y%m%d%H%M%S")"
mkdir "$app_dir"
echo "$TARGET_RUBY_VERSION" > "$app_dir/.ruby-version"
cd "$app_dir"

bundle init
bundle add rails --version "$TARGET_RAILS_VERSION"

if [[ "$TARGET_DATABASE_ADAPTER" == "postgresql" ]]; then
  bundle add pg
elif [[ "$TARGET_DATABASE_ADAPTER" == "mysql" ]]; then
  bundle add mysql2
else
  echo "Unsupported TARGET_DATABASE_ADAPTER: $TARGET_DATABASE_ADAPTER (must be 'postgresql' or 'mysql')"
  exit 1
fi

bundle exec rails new . \
  --skip-action-cable \
  --skip-action-mailbox \
  --skip-action-text \
  --skip-active-storage \
  --skip-action-mailer \
  --skip-active-job \
  --skip-javascript \
  --skip-hotwire \
  --skip-sprockets \
  --skip-spring \
  --skip-system-test \
  --skip-bootsnap \
  --skip-test \
  --force \
  --skip-bundle \
  --database="$TARGET_DATABASE_ADAPTER"

bundle install
bundle exec rails db:create
echo 'gem "outboxer", git: "https://github.com/fast-programmer/outboxer.git", branch: "master"' \
  >> Gemfile
bundle install
bundle exec rails generate outboxer:install
bundle exec rails db:migrate
bundle exec rails generate model Event
bundle exec rails db:migrate
bundle exec ruby -pi -e \
  "sub(/class Event < ApplicationRecord/, \"class Event < ApplicationRecord\\n  after_create { Outboxer::Message.queue(messageable: self) }\")" \
  app/models/event.rb

bundle exec rails runner <<'RUBY'
require "outboxer"

event = Event.create!

env = { "RAILS_ENV" => "test" }
publisher_cmd = File.join(Dir.pwd, "bin", "outboxer_publisher")
spawn(env, "ruby", publisher_cmd)

attempt = 1
max_attempts = 10
delay = 1

was_published = false

was_published = Outboxer::Message
    .list(status: :published)
    .fetch(:messages)
    .any? do |published_message|
      published_message[:messageable_type] == event.class.name &&
      published_message[:messageable_id] == event.id.to_s
    end

while (attempt <= max_attempts) && !was_published
    warn "Outboxer message not published yet. Retrying (#{attempt}/#{max_attempts})..."
    sleep delay
    attempt += 1

    was_published = Outboxer::Message
    .list(status: :published)
    .fetch(:messages)
    .any? do |published_message|
      published_message[:messageable_type] == event.class.name &&
      published_message[:messageable_id] == event.id.to_s
    end
end

exit(was_published ? 0 : 1)
RUBY

# TARGET_RUBY_VERSION=3.2.2 TARGET_RAILS_VERSION=7.1.5.1 TARGET_DATABASE_ADAPTER=postgresql ./quickstart_e2e_tests.sh
