# 📤 Outboxer

[![Gem Version](https://badge.fury.io/rb/outboxer.svg)](https://badge.fury.io/rb/outboxer)
[![Coverage Status](https://coveralls.io/repos/github/fast-programmer/outboxer/badge.svg)](https://coveralls.io/github/fast-programmer/outboxer)
[![Join our Discord](https://img.shields.io/badge/Discord-blue?style=flat&logo=discord&logoColor=white)](https://discord.gg/x6EUehX6vU)

**Outboxer** is a framework for migrating **Ruby on Rails** applications to **eventually consistent, event-driven architecture**.

It is an implementation of the [**transactional outbox pattern**](https://docs.aws.amazon.com/prescriptive-guidance/latest/cloud-design-patterns/transactional-outbox.html) and guarantees that for every event row inserted into your database, an asynchronous event handler is called at least once.

Whilst the generated publisher script integrates directly with Sidekiq, Outboxer is message broker agnostic and can easily be adapted to support Kafka and RabbitMQ.

## Installation

### 1. add gem to gemfile

```
gem 'outboxer'
```

### 2. install gem

```
bundle install
```

### 3. generate schema, publisher and tests

```bash
bin/rails g outboxer:install
```

### 4. migrate schema

```bash
bin/rails db:migrate
```

## Usage

### 1. derive new event

```ruby
# app/models/user_created_event.rb

class UserCreatedEvent < Event; end
```

### 2. define new event handler job

```ruby
# app/jobs/user_created_job.rb

class UserCreatedJob
  include Sidekiq::Job

  def perform(event_id)
    event = Event.find(event_id)

    Sidekiq.logger.info "UserCreatedJob#perform email=#{event.body['email']}"
  end
end
```

### 3. review event handler job routing

```ruby
# app/jobs/event_created_job.rb

class EventCreatedJob
  include Sidekiq::Job

  def perform(event_id, event_type)
    job_class_name = event_type.sub(/Event\z/, "Job")
    job_class = job_class_name.safe_constantize
    job_class.perform_async(event_id, event_type)
  end
end
```

### 4. start sidekiq

```bash
bin/sidekiq
```


### 5. start publisher

```bash
bin/outboxer_publisher
```

### 6. create new event

```ruby
UserCreatedEvent.create!(body: { 'email' => 'test@test.com' })
```

## Testing

To ensure you retain confidence in your stack, Outboxer generators create the following:

- **Unit Tests** (`spec/jobs/event_created_job_spec.rb`):  
  which validate that [`EventCreatedJob`](../../app/jobs/event_created_job.rb) correctly routes Events to Jobs.

- **End-to-End Tests** (`spec/bin/outboxer_publisher_spec.rb`):  
  which verify the full event lifecycle including creating events and handling them async.

## Management

Outboxer provides a sidekiq like UI to help manage your messages

### Publishers

<img width="1410" alt="Screenshot 2024-11-23 at 5 47 14 pm" src="https://github.com/user-attachments/assets/097946cf-e3e2-4ba2-a095-8176ef7e3178">

### Messages

<img width="1279" alt="Screenshot 2024-11-17 at 2 47 34 pm" src="https://github.com/user-attachments/assets/74deca7a-4299-41bd-ac58-401c670d72d9">

### rails

#### config/routes.rb

```ruby
require 'outboxer/web'

Rails.application.routes.draw do
  mount Outboxer::Web, at: '/outboxer'
end
```

### rack

#### config.ru

```ruby
require 'outboxer/web'

map '/outboxer' do
  run Outboxer::Web
end
```

## Contributing

Want to make Outboxer even better?

- ⭐ [Star the repo](https://github.com/fast-programmer/outboxer)
- 📮 [Check out open issues](https://github.com/fast-programmer/outboxer/issues)
- 💬 [Join our Discord](https://discord.gg/x6EUehX6vU) and say hey to `bedrock-adam`
- 🔭 [See our upcoming roadmap](https://github.com/orgs/fast-programmer/projects/4)

Contributions of all kinds are welcome including bug fixes, feature ideas, documentation improvements, and general feedback!

---

## License

This gem is available as open source under the terms of the  
[GNU Lesser General Public License v3.0](https://www.gnu.org/licenses/lgpl-3.0.html)
