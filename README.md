# Outboxer

[![Gem Version](https://badge.fury.io/rb/outboxer.svg)](https://badge.fury.io/rb/outboxer)
![Ruby](https://github.com/fast-programmer/outboxer/actions/workflows/master.yml/badge.svg)

## Background

Outboxer is an ActiveRecord implementation of the transactional outbox pattern for PostgreSQL and MySQL databases.

## Installation

### 1. add gem to gemfile

```
gem 'outboxer'
```

### 2. install gem

```
bundle install
```

## Set up

### 1. generate schema

```bash
bin/rails g outboxer:schema
```

### 2. migrate schema

```bash
bin/rake db:migrate
```

### 3. generate publisher

```bash
bin/rails g outboxer:publisher
```

###  4. after model creation, queue message

```ruby
class Event < ActiveRecord::Base
  # your existing model

  after_create do |event|
    Outboxer::Message.queue(messageable: event)
  end
end
```

### 5. publish message out of band

```ruby
Outboxer::Publisher.publish do |message|
  case message[:messageable_type]
  when 'Event'
    EventCreatedJob.perform_async({ 'id' => message[:messageable_id] })
  end
end
```

### 6. run publisher

```bash
bin/outboxer_publisher
```

## Management

Outboxer provides a sidekiq like UI to help manage your messages.

<img width="1257" alt="Screenshot 2024-05-20 at 8 47 57 pm" src="https://github.com/fast-programmer/outboxer/assets/394074/0446bc7e-9d5f-4fe1-b210-ff394bdacdd6">

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
