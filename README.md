# Outboxer

[![Gem Version](https://badge.fury.io/rb/outboxer.svg)](https://badge.fury.io/rb/outboxer)
![Ruby](https://github.com/fast-programmer/outboxer/actions/workflows/master.yml/badge.svg)

## Background

Outboxer is an ActiveRecord implementation of the [transactional outbox pattern](https://microservices.io/patterns/data/transactional-outbox.html).

It helps you quickly migrate conventional Rails apps to an eventually consistent, event driven architecture based on best practice domain driven design (DDD) principles.

## Installation

### add the gem to your application's gemfile

```
gem 'outboxer'
```

### install the gem

```
bundle install
```

## Usage

### generate the schema

```bash
bin/rails g outboxer:schema
```

### migrate the schema

```bash
bin/rake db:migrate
```

### create an outboxer message in the same transaction as the event record

```ruby
class Event < ActiveRecord::Base
  # ...

  after_create do |event|
    Outboxer::Message.backlog!(messageable_type: event.class.name, messageable_id: event.id)
  end
end
```

### define an event created job

```ruby
class EventCreatedJob
  include Sidekiq::Job

  def perform(args)
    event = Event.find(args['id'])

    # ...
  end
end
```

### generate the sidekiq publisher

```bash
bin/rails g outboxer:sidekiq_publisher
```


### update the publish block to add an event created job

```ruby
Outboxer::Publisher.publish! do |outboxer_message|
  case outboxer_message.messageable_type
  when 'Event'
    EventCreatedJob.perform_async({ 'id' => outboxer_message.messageable_id })
  end
end
```

### run the sidekiq publisher

```bash
bin/sidekiq_publisher
```

## Motivation

Outboxer was created to help Rails teams migrate to eventually consistent event driven architecture quickly, using existing tools and infrastructure.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/fast-programmer/outboxer. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/fast-programmer/outboxer/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Outboxer project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/fast-programmer/outboxer/blob/main/CODE_OF_CONDUCT.md).
