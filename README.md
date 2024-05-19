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

###  3. after event created, create outbox(er) message

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

### 6. update publish block to queue event created job

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

### 7. mount the ui

manage and monitor outboxer messages

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

## Motivation

Outboxer was created to help Rails teams migrate to eventually consistent event driven architecture quickly, using existing tools and infrastructure.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/fast-programmer/outboxer. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/fast-programmer/outboxer/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Outboxer project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/fast-programmer/outboxer/blob/main/CODE_OF_CONDUCT.md).
