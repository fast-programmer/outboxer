# Outboxer

[![Gem Version](https://badge.fury.io/rb/outboxer.svg)](https://badge.fury.io/rb/outboxer)
![Ruby](https://github.com/fast-programmer/outboxer/actions/workflows/master.yml/badge.svg)

## Background

Outboxer is an ActiveRecord implementation of the [transactional outbox pattern](https://microservices.io/patterns/data/transactional-outbox.html) for PostgreSQL and MySQL databases.

## Installation

### 1. add gem to gemfile

```
gem 'outboxer'
```

### 2. install gem

```
bundle install
```

## Usage

### 1. generate schema

```bash
bin/rails g outboxer:schema
```

### 2. migrate schema

```bash
bin/rake db:migrate
```

###  3. queue message after event created

```ruby
class Event < ActiveRecord::Base
  # your existing model

  after_create do |event|
    Outboxer::Message.queue(messageable: event)
  end
end
```

### 4. generate publisher

```bash
bin/rails g outboxer:publisher
```

### 5. handle message in out of band publish block

```ruby
Outboxer::Publisher.publish do |message|
  # handle Event.find(message[:messageable_id]) here
end
```

### 6. periodically delete published messages

run every x interval in your existing scheduling infrastructure

```ruby
  Outboxer::Messages.delete_all(
    status: :published,
    batch_size: 100,
    older_than: Time.now - retention_period)
```

see wiki for how to call in sidekiq scheduler, whenever, clockwork and custom process examples

### 7. run publisher

```bash
bin/outboxer_publisher
```

### 8. manage messages

manage messages with the web ui

<img width="1257" alt="Screenshot 2024-05-20 at 8 47 57 pm" src="https://github.com/fast-programmer/outboxer/assets/394074/0446bc7e-9d5f-4fe1-b210-ff394bdacdd6">

#### rails

##### config/routes.rb

```ruby
require 'outboxer/web'

Rails.application.routes.draw do
  mount Outboxer::Web, at: '/outboxer'
end
```

#### rack

##### config.ru

```ruby
require 'outboxer/web'

map '/outboxer' do
  run Outboxer::Web
end
```

### 9. monitor message publisher

know how much memory and cpu is required by the publisher

<img width="310" alt="Screenshot 2024-05-20 at 10 41 57 pm" src="https://github.com/fast-programmer/outboxer/assets/394074/1222ad47-15e3-44d1-bb45-6abc6b3e4325">

```bash
run bin/outboxer_publishermon
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/fast-programmer/outboxer.

## License

This gem is available as open source under the terms of the [GNU Lesser General Public License v3.0](https://www.gnu.org/licenses/lgpl-3.0.html).
