# Outboxer

[![Gem Version](https://badge.fury.io/rb/outboxer.svg)](https://badge.fury.io/rb/outboxer)
![Ruby](https://github.com/fast-programmer/outboxer/actions/workflows/master.yml/badge.svg)

## Background

Outboxer is a Rails 7 implementation of the transactional outbox pattern.

## Setup

### 1. add gem to gemfile

```
gem 'outboxer'
```

### 2. install gem

```
bundle install
```

### 3. generate schema and publisher

```bash
bin/rails g outboxer:install
```

### 4. migrate schema

```bash
bin/rake db:migrate
```

### 5. Publish message to redis via sidekiq job

```ruby
Outboxer::Publisher.publish do |message|
  OutboxerIntegration::PublishMessageJob.perform_async({
    'message_id' => message[:id],
    'messageable_id' => message[:messageable_id],
    'messageable_type' => message[:messageable_type] })
end
```

### 6. route message to handler via sidekiq job

```ruby
module OutboxerIntegration
  class PublishMessageJob
    include Sidekiq::Job

    def perform(args)
      # route message to job handler
    end
  end
end
```

### 7. run publisher

```bash
bin/outboxer_publisher
```

### 8. run sidekiq

```bash
bin/sidekiq
```

### 9. open rails console

```bash
bin/rails c
```

### 10. create test started event

```ruby
OutboxerIntegration::TestStartedEvent.create!
```

```
TRANSACTION (0.2ms)  BEGIN
OutboxerIntegration::TestStartedEvent Create (1.2ms)  INSERT INTO "events" ....
Outboxer::Models::Message Create (1.8ms)  INSERT INTO "outboxer_messages" ...
TRANSACTION (0.4ms)  COMMIT
=>
#<OutboxerIntegration::TestStartedEvent:0x000000010a329eb0
 id: 1,
 user_id: nil,
 tenant_id: nil,
 type: "OutboxerIntegration::TestStartedEvent",
 body: nil,
 created_at: Sat, 21 Dec 2024 09:11:56.459083000 UTC +00:00>
```

### 11. Observe published message


Confirm the message has been published out of band e.g.

```
2024-12-21T09:12:01.303Z pid=13171 tid=publisher-1 INFO: Outboxer published message 1 to sidekiq for OutboxerIntegration::TestStartedEvent::1
```

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

Bug reports and pull requests are welcome on GitHub at https://github.com/fast-programmer/outboxer.

## License

This gem is available as open source under the terms of the [GNU Lesser General Public License v3.0](https://www.gnu.org/licenses/lgpl-3.0.html).
