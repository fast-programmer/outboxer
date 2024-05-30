# Outboxer

[![Gem Version](https://badge.fury.io/rb/outboxer.svg)](https://badge.fury.io/rb/outboxer)
![Ruby](https://github.com/fast-programmer/outboxer/actions/workflows/master.yml/badge.svg)

## Background

Outboxer is an ActiveRecord implementation of the [transactional outbox pattern](https://microservices.io/patterns/data/transactional-outbox.html).

It was built to help Rails teams migrate to eventually consistent event driven architecture quickly, using existing tools and infrastructure.

## Installation

### 1. add the gem to your application's gemfile

```
gem 'outboxer'
```

### 2. install the gem

```
bundle install
```

## Usage

### 1. generate the schema

```bash
bin/rails g outboxer:schema
```

### 2. migrate the schema

```bash
bin/rake db:migrate
```

###  3. after an event model is created in your application, backlog an outboxer message

```ruby
class Event < ActiveRecord::Base
  # ...

  after_create do |event|
    Outboxer::Message.backlog(messageable: event)
  end
end
```

### 4. generate the message publisher

```bash
bin/rails g outboxer:message_publisher
```

### 5. update the publish block to perform an event created job async

```ruby
Outboxer::Publisher.publish do |message|
  case message[:messageable_type]
  when 'Event'
    EventCreatedJob.perform_async({ 'id' => message[:messageable_id] })
  end
end
```

### 6. add the event created job

```ruby
class EventCreatedJob
  include Sidekiq::Job

  def perform(args)
    event = Event.find(args['id'])

    # ...
  end
end
```

### 7. run the message publisher

```bash
bin/outboxer_message_publisher
```

### 8. manage the messages

manage backlogged, queued, publishing and failed messages with the web ui

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

### 9. monitor the message publisher

understanding how much memory and cpu is required by the message publisher

<img width="310" alt="Screenshot 2024-05-20 at 10 41 57 pm" src="https://github.com/fast-programmer/outboxer/assets/394074/1222ad47-15e3-44d1-bb45-6abc6b3e4325">

```bash
run bin/outboxer_message_publishermon
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/fast-programmer/outboxer.

## License

This gem is available as open source under the terms of the [GNU Lesser General Public License v3.0](https://www.gnu.org/licenses/lgpl-3.0.html).
