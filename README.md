# 📤 Outboxer

[![Gem Version](https://badge.fury.io/rb/outboxer.svg)](https://badge.fury.io/rb/outboxer)
[![Coverage Status](https://coveralls.io/repos/github/fast-programmer/outboxer/badge.svg)](https://coveralls.io/github/fast-programmer/outboxer)
[![Join our Discord](https://img.shields.io/badge/Discord-blue?style=flat&logo=discord&logoColor=white)](https://discord.gg/x6EUehX6vU)

**Outboxer** is a **high-reliability, high-performance** implementation of the [**transactional outbox pattern**](https://docs.aws.amazon.com/prescriptive-guidance/latest/cloud-design-patterns/transactional-outbox.html) for **Ruby on Rails** applications.

It ensures **at-least-once delivery** of messages across **distributed systems** such as PostgreSQL, MySQL, Redis, RabbitMQ and Kafka.

# 🚀 Quickstart

**1. Install**

```bash
bundle add outboxer
bundle install
bin/rails g outboxer:install
bin/rails db:migrate
```

**2. Queue messages**

```ruby
# app/models/event.rb

class Event < ApplicationRecord
  after_create { Outboxer::Message.queue(messageable: self) }
end
```

Example:

```
# bin/rails c

irb(main):001:0> Event.create!
  TRANSACTION              (0.2ms)  BEGIN
  Event Create             (1.0ms)  INSERT INTO "events" ...
  Outboxer::Message Create (0.8ms)  INSERT INTO "outboxer_messages" ...
  TRANSACTION              (0.3ms)  COMMIT
=> #<Event id: 1, ...>
```

**3. Publish messages**

```ruby
# bin/outboxer_publisher

Outboxer::Publisher.publish_message do |message|
  # Publish message to Sidekiq, Kafka, RabbitMQ, etc
end
```

# 📊 Web Dashboard

Monitor publishers and messages with a lightweight built-in UI.

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

# 🤝 Contributing

- ⭐ [Star us on GitHub](https://github.com/fast-programmer/outboxer)
- 🐛 [Report issues](https://github.com/fast-programmer/outboxer/issues)
- 💬 [Chat on Discord](https://discord.gg/x6EUehX6vU)

All contributions are welcome!

# ⚖️ License

Open-sourced under [LGPL v3.0](https://www.gnu.org/licenses/lgpl-3.0.html).

# 🏁 Why Outboxer?

- Production-hardened
- Lightweight and easy to integrate
- Scales to millions of messages
- Built to survive crashes, outages, and scale
