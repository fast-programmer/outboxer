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

### 5. run publisher

```bash
bin/outboxer_publisher
```

### 6. run sidekiq

```bash
bin/sidekiq
```

### 7. open rails console

```bash
bin/rails c
```

### 8. start test

```ruby
OutboxerIntegration::Test.start
```

```
TRANSACTION (0.5ms)  BEGIN
OutboxerIntegration::Test Create             (1.9ms)  INSERT INTO "outboxer_integration_tests" ...
OutboxerIntegration::TestStartedEvent Create (1.8ms)  INSERT INTO "events" ...
Outboxer::Models::Message Create             (3.2ms)  INSERT INTO "outboxer_messages" ...
TRANSACTION (0.7ms)  COMMIT
=> {:id=>1, :events=>[{:id=>1, :type=>"OutboxerIntegration::TestStartedEvent"}]}
```

### 9. ensure test completed

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
