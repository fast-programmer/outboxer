# Outboxer

[![Gem Version](https://badge.fury.io/rb/outboxer.svg)](https://badge.fury.io/rb/outboxer)
[![Coverage Status](https://coveralls.io/repos/github/fast-programmer/outboxer/badge.svg)](https://coveralls.io/github/fast-programmer/outboxer)
[![Join our Discord](https://img.shields.io/badge/Discord-blue?style=flat&logo=discord&logoColor=white)](https://discord.gg/x6EUehX6vU)

**Outboxer** is a framework for migrating **Ruby on Rails** applications to **eventually consistent, event-driven architecture**.

It is an implementation of the [**transactional outbox pattern**](https://docs.aws.amazon.com/prescriptive-guidance/latest/cloud-design-patterns/transactional-outbox.html) designed for high reliability and performance in production environments.

## Why Outboxer?

You’ve probably seen this code before

```ruby
user_created_event = UserCreatedEvent.create!(...)

# ☠️ process crashes

UserCreatedJob.perform_async(user_created_event.id)
```

Welcome to the dual-write problem — when the database and message queue gets out of sync.

Outboxer solves this by:

* ✅ Writing the event and queuing the job in the same transaction
* ✅ Guaranteeing delivery via a resilient outbox + Sidekiq
* ✅ Letting you focus on your business logic, not infrastructure

## 💡 Usage Example

### 1. Queue an outboxer message after an event is created

```ruby
# app/event.rb

class Event < ApplicationRecord
  after_create do |event|
    Outboxer::Message.queue(messageable: event)
  end
end
```

This ensures an event is always created in the same transaction as the queued outboxer message referencing it.

### 2. Define a new event

```ruby
# app/models/user_created_event.rb

class UserCreatedEvent < Event; end
```

### 3. Define a new job to handle the new event

```ruby
# app/jobs/user_created_job.rb

class UserCreatedJob
  include Sidekiq::Job

  def perform(event_id, event_type)
    # your code to handle UserCreatedEvent here
  end
end
```

### 4. Route the new event to the new job

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

### 5. Queue the event created job in the outboxer_publisher script block

```ruby
# bin/publisher

Outboxer::Publisher.publish_message(...) do |message|
  EventCreatedJob.perform_async(
    message[:messageable_id], message[:messageable_type])
end
```

### 6. Run services

```bash
bin/sidekiq
bin/outboxer_publisher
```

### 7. Create new event in console

```ruby
# bin/rails c

UserCreatedEvent.create!
```

### 8. Observe logs

```sql
TRANSACTION               (0.5ms)  BEGIN
UserCreatedEvent  Create  (1.8ms)  INSERT INTO "events" ...
Outboxer::Message Create  (3.2ms)  INSERT INTO "outboxer_messages" ...
TRANSACTION               (0.7ms)  COMMIT
```

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


## 🧪 Testing

### 1. start test

```ruby
OutboxerIntegration::TestService.start
```

```
TRANSACTION (0.5ms)  BEGIN
OutboxerIntegration::Test Create             (1.9ms)  INSERT INTO "outboxer_integration_tests" ...
OutboxerIntegration::TestStartedEvent Create (1.8ms)  INSERT INTO "events" ...
Outboxer::Message Create                     (3.2ms)  INSERT INTO "outboxer_messages" ...
TRANSACTION (0.7ms)  COMMIT
=> {:id=>1, :events=>[{:id=>1, :type=>"OutboxerIntegration::TestStartedEvent"}]}
```

### 2. ensure test completes

```
OutboxerIntegration::Test.find(1).events
=>
[#<OutboxerIntegration::TestStartedEvent:0x0000000105749158
  id: 1,
  user_id: nil,
  tenant_id: nil,
  eventable_type: "OutboxerIntegration::Test",
  eventable_id: 1,
  type: "OutboxerIntegration::TestStartedEvent",
  body: {"test"=>{"id"=>1}},
  created_at: 2025-01-11 23:37:36.009745 UTC>,
 #<OutboxerIntegration::TestCompletedEvent:0x0000000105748be0
  id: 2,
  user_id: nil,
  tenant_id: nil,
  eventable_type: "OutboxerIntegration::Test",
  eventable_id: 1,
  type: "OutboxerIntegration::TestCompletedEvent",
  body: {"test"=>{"id"=>1}},
  created_at: 2025-01-11 23:48:38.750419 UTC>]
```

### 3. run spec

```bin/rspec spec/outboxer_integration/test_started_spec.rb```

This is what the generated spec is testing, to continue to ensure you have end to end confidence in your stack.

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

## 🤝 Contributing

Want to make Outboxer even better?

- ⭐ [Star the repo](https://github.com/fast-programmer/outboxer)
- 📮 [Check out open issues](https://github.com/fast-programmer/outboxer/issues)
- 💬 [Join our Discord](https://discord.gg/x6EUehX6vU) and say hey to `bedrock-adam`
- 🔭 [See our upcoming roadmap](https://github.com/orgs/fast-programmer/projects/4)

Contributions of all kinds are welcome including bug fixes, feature ideas, documentation improvements, and general feedback!

---

## ⚖ License

This gem is available as open source under the terms of the  
[GNU Lesser General Public License v3.0](https://www.gnu.org/licenses/lgpl-3.0.html)
