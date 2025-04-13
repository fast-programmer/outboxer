# Outboxer

[![Gem Version](https://badge.fury.io/rb/outboxer.svg)](https://badge.fury.io/rb/outboxer)
[![Coverage Status](https://coveralls.io/repos/github/fast-programmer/outboxer/badge.svg)](https://coveralls.io/github/fast-programmer/outboxer)
[![Join our Discord](https://img.shields.io/badge/Discord-blue?style=flat&logo=discord&logoColor=white)](https://discord.gg/x6EUehX6vU)

## Background

Outboxer is designed to be **Ruby's fastest and most reliable SQL event publisher**.

It addresses the *dual write problem* that occurs in event driven Ruby on Rails applications where an event:

1. row must be inserted into a PostgreSQL or MySQL database table
2. must be handled out of band (e.g. in a Sidekiq Job via redis)

By providing *a ruby interface to queue events* in your application services, and *a multithreaded publisher script* to publish them out of band,
Outboxer quickly transforms your existing stack to *eventually consistent architecture*, bringing with it all the benefits of high availability, scalability and resilience.

See the [transactional outbox pattern](https://docs.aws.amazon.com/prescriptive-guidance/latest/cloud-design-patterns/transactional-outbox.html) for more details.

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
bin/rake db:migrate
```

## Usage

### 1. queue outboxer message in after_save callback of event

```ruby
class Event < ApplicationRecord
  after_create do |event|
    Outboxer::Message.queue(messageable: event)
  end
end
```

### 2. Review message publisher conventions

By default, the publisher will perform sidekiq jobs asynchronously, based on the convention below:

`Context::ResourceVerbEvent -> Context::ResourceVerbJob`

#### Examples:

```
1. Accountify::InvoiceCreatedEvent -> Accountify::InvoiceCreatedJob
2. Accountify::InvoiceUpdatedEvent -> Accountify::InvoiceUpdatedJob
3. Accountify::ContactCreatedEvent -> Accountify::ContactUpdatedJob
```


### 3. Review bin/publisher block

```ruby
Outboxer::Publisher.publish_message(
  buffer: options[:buffer],
  concurrency: options[:concurrency],
  tick: options[:tick],
  poll: options[:poll],
  heartbeat: options[:heartbeat],
  logger: logger) do |message|
    OutboxerIntegration::PublishMessageJob.perform_async({
      "message_id" => message[:id],
      "messageable_id" => message[:messageable_id],
      "messageable_type" => message[:messageable_type]
    })
  end
```

### 4. run publisher

```bash
bin/outboxer_publisher
```

For a comprehensive list of settings, see [publisher options](https://github.com/fast-programmer/outboxer/wiki/Sidekiq-publisher-options).

### 5. run sidekiq

```bash
bin/sidekiq
```

### 6. open rails console

```bash
bin/rails c
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

This is what the generated spec is testing, to ensure you have confidence in your stack.

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
