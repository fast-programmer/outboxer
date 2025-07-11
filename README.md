# 📤 Outboxer

[![Gem Version](https://badge.fury.io/rb/outboxer.svg)](https://badge.fury.io/rb/outboxer)
[![Coverage Status](https://coveralls.io/repos/github/fast-programmer/outboxer/badge.svg)](https://coveralls.io/github/fast-programmer/outboxer)
[![Join our Discord](https://img.shields.io/badge/Discord-blue?style=flat&logo=discord&logoColor=white)](https://discord.gg/x6EUehX6vU)

**Outboxer** is an implementation of the [transactional outbox pattern](https://docs.aws.amazon.com/prescriptive-guidance/latest/cloud-design-patterns/transactional-outbox.html) for **Ruby on Rails** applications.

It helps you migrate to **event-driven architecture** with at least once delivery guarantees.

# Quickstart

**1. Install gem**

```bash
bundle add outboxer
bundle install
```

**2. Generate schema migrations, publisher script and tests**

```bash
bundle exec rails g outboxer:install
```

**3. Migrate database**

```bash
bundle exec rails db:migrate
```

**4. Generate event schema and model**

```bash
bundle exec rails generate model Event type:string created_at:datetime --skip-timestamps
bundle exec rails db:migrate
```

**5. Queue outboxer message after event created**

```ruby
# app/models/event.rb

class Event < ApplicationRecord
  after_create do |event|
    Outboxer::Message.queue(messageable: event)
  end
end
```

**6. Derive event type**

```ruby
# app/models/accountify/invoice_raised_event.rb

module Accountify
  class InvoiceRaisedEvent < Event; end
end
```

**7. Create derived event type**

```bash
bundle exec rails c
```

```ruby
ActiveRecord::Base.logger = Logger.new(STDOUT)

Accountify::InvoiceRaisedEvent.create!(created_at: Time.current)
```

**8. Observe transactional consistency**

```log
TRANSACTION                (0.2ms)  BEGIN
Event Create               (0.4ms)  INSERT INTO "events" ...
Outboxer::Message Create   (0.3ms)  INSERT INTO "outboxer_messages" ...
TRANSACTION                (0.2ms)  COMMIT
```

**8. Publish outboxer messages**

```ruby
# bin/outboxer_publisher

Outboxer::Publisher.publish_messages do |publisher, message_batch|
  begin
    # TODO: publish messages here
  rescue => error
    Outboxer::Publisher.messages_failed_by_ids(
      id: publisher[:id], name: publisher[:name],
      message_ids: message_batch[:message_ids], exception: error)
  else
    Outboxer::Publisher.messages_published_by_ids(
      id: publisher[:id], name: publisher[:name],
      message_ids: message_batch[:message_ids])
  end
end
```

To integrate with Sidekiq, Bunny, Kafka and AWS SQS see the [publisher block examples](https://github.com/fast-programmer/outboxer/wiki/Outboxer-publisher-block-examples).

# Testing

To ensure you have end to end coverage:

`bundle exec rspec spec/bin/outboxer_publisher`

# Monitoring

Monitor using the built-in web UI:

## Publishers

<img width="1288" alt="Screenshot 2025-04-30 at 6 25 06 pm" src="https://github.com/user-attachments/assets/a3844b78-82aa-4b08-9b6d-f71d6829d31f" />

## Messages

<img width="1290" alt="Screenshot 2025-04-30 at 6 25 37 pm" src="https://github.com/user-attachments/assets/9ccfc7e5-abd4-4a21-9dfe-7916044b1096" />

**Rails**

```ruby
# config/routes.rb

require 'outboxer/web'

mount Outboxer::Web, at: '/outboxer'
```

**Rack**

```ruby
# config.ru

require 'outboxer/web'

map '/outboxer' { run Outboxer::Web }
```

# Contributing

* [Star us on GitHub](https://github.com/fast-programmer/outboxer)
* [Report issues](https://github.com/fast-programmer/outboxer/issues)
* [Chat on Discord](https://discord.gg/x6EUehX6vU)

All contributions are welcome!

# License

Open-sourced under [LGPL v3.0](https://www.gnu.org/licenses/lgpl-3.0.html).
