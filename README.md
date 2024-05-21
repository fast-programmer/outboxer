# Outboxer

[![Gem Version](https://badge.fury.io/rb/outboxer.svg)](https://badge.fury.io/rb/outboxer)
![Ruby](https://github.com/fast-programmer/outboxer/actions/workflows/master.yml/badge.svg)

## Background

Outboxer is an ActiveRecord implementation of the [transactional outbox pattern](https://microservices.io/patterns/data/transactional-outbox.html).

## Installation

### 1. add gem to your application's gemfile

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

###  3. after event created, backlog message

```ruby
class Event < ActiveRecord::Base
  # ...

  after_create do |event|
    Outboxer::Message.backlog(
      messageable_type: event.class.name,
      messageable_id: event.id)
  end
end
```

### 4. add event created job

```ruby
class EventCreatedJob
  include Sidekiq::Job

  def perform(args)
    event = Event.find(args['id'])

    # ...
  end
end
```

### 5. generate message publisher

```bash
bin/rails g outboxer:message_publisher
```

### 6. update publish block to perform event created job async

```ruby
Outboxer::Publisher.publish do |message|
  case message[:messageable_type]
  when 'Event'
    EventCreatedJob.perform_async({ 'id' => message[:messageable_id] })
  end
end
```

### 6. run message publisher

```bash
bin/outboxer_message_publisher
```

### 7. manage messages

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

### 8. monitor message publisher

understanding how much memory and cpu is required by the message publisher

<img width="310" alt="Screenshot 2024-05-20 at 10 41 57 pm" src="https://github.com/fast-programmer/outboxer/assets/394074/1222ad47-15e3-44d1-bb45-6abc6b3e4325">

```bash
run bin/outboxer_message_publishermon
```

## Motivation

Outboxer was created to help Rails teams migrate to eventually consistent event driven architecture quickly, using existing tools and infrastructure.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/fast-programmer/outboxer. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/fast-programmer/outboxer/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Outboxer project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/fast-programmer/outboxer/blob/main/CODE_OF_CONDUCT.md).
