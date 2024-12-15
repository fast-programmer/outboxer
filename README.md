# Outboxer

[![Gem Version](https://badge.fury.io/rb/outboxer.svg)](https://badge.fury.io/rb/outboxer)
![Ruby](https://github.com/fast-programmer/outboxer/actions/workflows/master.yml/badge.svg)

## Background

Outboxer is an ActiveRecord implementation of the transactional outbox pattern for PostgreSQL and MySQL databases.

## Setup

### 1. add gem to gemfile

```
gem 'outboxer'
```

### 2. install gem

```
bundle install
```

### 3. generate schema

```bash
bin/rails g outboxer:schema
```

### 4. migrate schema

```bash
bin/rake db:migrate
```

### 5. seed database

```bash
bin/rake outboxer:db:seed
```

###  6. queue message after event creation

#### new event

```bash
bin/rails g outboxer:event
```

#### existing event

```ruby
class Event < ActiveRecord::Base
  after_create do |event|
    Outboxer::Message.queue(messageable: event)
  end
end
```

### 7. generate publisher

#### sidekiq

```bash
bin/rails g outboxer:sidekiq_publisher
```

#### custom

```bash
bin/rails g outboxer:publisher
```

### 8. publish message out of band

#### Sidekiq

```ruby
Outboxer::Publisher.publish do |message|
  OutboxerIntegration::Message::PublishJob.perform_async(message)
end
```

#### Custom

```ruby
Outboxer::Publisher.publish do |message|
  # publish message to custom broker here
end
```

### 9. run publisher

```bash
bin/outboxer_publisher
```

### 10. open rails console

```bash
bin/rails c
```

### 11. create event

```ruby
Event.create!
```

### 12. Observe published message

Confirm the message has been published out of band

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
