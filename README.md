# 📤 Outboxer

[![Gem Version](https://badge.fury.io/rb/outboxer.svg)](https://badge.fury.io/rb/outboxer)
[![Coverage Status](https://coveralls.io/repos/github/fast-programmer/outboxer/badge.svg)](https://coveralls.io/github/fast-programmer/outboxer)
[![Join our Discord](https://img.shields.io/badge/Discord-blue?style=flat&logo=discord&logoColor=white)](https://discord.gg/x6EUehX6vU)

**Outboxer** is a battle-tested implementation of the [**transactional outbox pattern**](https://docs.aws.amazon.com/prescriptive-guidance/latest/cloud-design-patterns/transactional-outbox.html) for **Ruby on Rails** applications.

It helps you quickly migrate to eventually consistent, event-driven architecture — gaining resilience, fault tolerance, and scalability without the fear of lost messages, data corruption, or sleepless nights.

# 🚀 Quickstart

**1. Install gem**

```bash
bundle add outboxer
bundle install
```

**2. Generate schema migrations, publisher script and tests**

```bash
bin/rails g outboxer:install
```

**3. Migrate database**

```bash
bin/rails db:migrate
```

**4. Generate messageable schema and model**

```bash
bin/rails generate model Event
bin/rails db:migrate
```

**5. Queue message after messageable is created**

```ruby
# app/models/event.rb

class Event < ApplicationRecord
  after_create { Outboxer::Message.queue(messageable: self) }
end
```

**6. Publish messages**

```ruby
# bin/outboxer_publisher

Outboxer::Publisher.publish_message(...) do |message|
  # TODO: publish message here

  logger.info "Outboxer published message " \
    "id=#{message[:id]} " \
    "messageable_type=#{message[:messageable_type]} " \
    "messageable_id=#{message[:messageable_id]} "
end
```

# 🧪 Testing

The generated `spec/bin/outboxer_publisher` adds end to end queue and publish message test coverage.

# 📈 Monitoring

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
