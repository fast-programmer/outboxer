# Outboxer

[![Gem Version](https://badge.fury.io/rb/outboxer.svg)](https://badge.fury.io/rb/outboxer)
[![Coverage Status](https://coveralls.io/repos/github/fast-programmer/outboxer/badge.svg)](https://coveralls.io/github/fast-programmer/outboxer)
[![Join our Discord](https://img.shields.io/badge/Discord-blue?style=flat&logo=discord&logoColor=white)](https://discord.gg/x6EUehX6vU)

## Background

**Outboxer** is an implementation of the [transactional outbox pattern](https://docs.aws.amazon.com/prescriptive-guidance/latest/cloud-design-patterns/transactional-outbox.html) for event driven Ruby on Rails applications.

It addresses the [*dual write problem*](https://www.confluent.io/blog/dual-write-problem/) that can occur when an event row is inserted into the database, but queueing the event handler job into redis failed.

```ruby
event = Event.create!(...)

# ☠️ process crashes

EventCreatedJob.perform_async(event.id)
# ❌ job was not queued to redis
# 🪲 downstream state is now inconsistent
```

## How it works

### 1. When an event is created, an outboxer message is queued in the same transaction

The `queued` `Outboxer::Message` record is polymorphically associated to the `Event` and is created automatically in the **same database transaction** using an `after_create` callback e.g.

```ruby
# app/event.rb

class Event < ApplicationRecord
  after_create do |event|
    Outboxer::Message.queue(messageable: event)
  end
end
```

### 2. Queued outboxer messages are published out of band

A high performance, multithreaded publisher script then publishes those queued messages e.g.

```ruby
# bin/publisher

Outboxer::Publisher.publish_message(...) do |message|
  EventCreatedJob.perform_async(...)
end
```

For more details, see the wiki page: [How Outboxer works](https://github.com/fast-programmer/outboxer/wiki/How-outboxer-works)

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

## Usage

### 1. review generated event schema and model

#### Event schema

```ruby
# db/migrate/create_events.rb

class CreateEvents < ActiveRecord::Migration[7.0]
  def up
    create_table :events do |t|
      t.bigint :user_id
      t.bigint :tenant_id

      t.string :eventable_type, limit: 255
      t.bigint :eventable_id
      t.index [:eventable_type, :eventable_id]

      t.string :type, null: false, limit: 255
      t.send(json_column_type, :body)
      t.datetime :created_at, null: false
    end
  end

  # ...
end
```

#### Event model

```ruby
# app/models/event.rb

class Event < ApplicationRecord
  self.table_name = "events"

  # associations

  belongs_to :eventable, polymorphic: true

  # validations

  validates :type, presence: true, length: { maximum: 255 }

  # callbacks

  after_create do |event|
    Outboxer::Message.queue(messageable: event)
  end
end
```

### 2. migrate schema

```bash
bin/rake db:migrate
```

### 3. define new event using STI

```ruby
# app/models/accountify/contact_created_event.rb

module Accountify
  class ContactCreatedEvent < Event
  end
end
```

### 4. create new event in application service

```ruby
# app/services/accountify/contact_service.rb

module Accountify
  module ContactService
    module_function

    def create(user_id:, tenant_id:, email:)
      ActiveRecord::Transaction.execute do
        contact = Contact.create!(tenant_id: tenant_id, email: email)

        event = ContactCreatedEvent.create!(
          user_id: user_id, tenant_id: tenant_id,
          eventable: contact, body: { "email" => email }
        )

        [contact, event]
      end
    end
  end
end
```

```
contact, event = Accountiy::ContactService.create(...)
```

### 5. add event created job to route event

Following the convention `Context::ResourceVerbEvent -> Context::ResourceVerbJob`

```ruby
# app/jobs/accountify/contact_created_job.rb

module Accountify
  class ContactCreatedJob
    include Sidekiq::Job

    def perform_async(args)
      # your handler code here
    end
  end
end
```

**Note:** this can be customised in the generated `OutboxerIntegration::PublishMessageJob`

### 6. run publisher

```bash
bin/outboxer_publisher
```

**Note:** The outboxer publisher supports many [options](https://github.com/fast-programmer/outboxer/wiki/Sidekiq-publisher-options).

### 7. run sidekiq

```bash
bin/sidekiq
```

**Note:** Enabling [superfetch](https://github.com/sidekiq/sidekiq/wiki/Reliability#using-super_fetch) is strongly recommend, to preserve consistency across services.

### 8. open rails console

```bash
bin/rails c
```

### 9. call service

```ruby
contact, event = Accountify::ContactService.create(user_id: 1, tenant_id: 1, email: 'test@test.com')
```

### 10. observe transactional consistency

```
TRANSACTION (0.5ms)  BEGIN
Accountify::Contact Create             (1.9ms)  INSERT INTO "accountify_contacts" ...
Accountify::ContactCreatedEvent Create (1.8ms)  INSERT INTO "events" ...
Outboxer::Message Create               (3.2ms)  INSERT INTO "outboxer_messages" ...
TRANSACTION (0.7ms)  COMMIT
=> {:id=>1, :events=>[{:id=>1, :type=>"Accountify::ContactCreatedEvent"}]}
```

## Testing

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

## Contributing

If you'd like to help out, take a look at the project's [open issues](https://github.com/fast-programmer/outboxer/issues).

Also [join our discord](https://discord.gg/x6EUehX6vU) and ping `bedrock-adam` if you'd like to contribute to [upcoming features](https://github.com/orgs/fast-programmer/projects/4).

## License

This gem is available as open source under the terms of the [GNU Lesser General Public License v3.0](https://www.gnu.org/licenses/lgpl-3.0.html).
