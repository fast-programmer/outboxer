# Outboxer

[![Gem Version](https://badge.fury.io/rb/outboxer.svg)](https://badge.fury.io/rb/outboxer)
![Ruby](https://github.com/fast-programmer/outboxer/actions/workflows/master.yml/badge.svg)

## Background

Outboxer helps teams migrate existing Ruby on Rails apps to event-driven architecture ASAP.

It guarantees an eventual consistency model, where no events are lost even when updates span SQL and Redis.

## Problem

To support an eventually consistent event driven architecture, an application service often needs to:

1. create or update a `Model` row in an _SQL table_
1. create an `Event` row in an _SQL table_
2. queue a `Worker` entry in _Redis set_


As these operations span multiple database types (_SQL_ and _Redis_) however, they can not be combined into a single atomic operation using a transaction. If either database fails, inconsistencies can occur.

## Solution

Outboxer is an `ActiveRecord` implementation of the [transactional outbox pattern](https://microservices.io/patterns/data/transactional-outbox.html): a well established solution to this problem.

By creating an outboxer message in the same transaction as an event, we can guarantee the event is published out to another system _eventually_, even if there are failures.

### Getting started

### Installation

#### add the outboxer gem to your application's Gemfile:

```
gem 'outboxer'
```

#### install the outboxer gem:

```
bundle install
```

### Usage

#### 1. add events to your model

##### a. migrate schema

```bash
bin/rails g migration create_events
```

```ruby
class CreateEvents < ActiveRecord::Migration[6.1]
  def change
    create_table :events, force: true do |t|
      t.text :type, null: false
      t.jsonb :payload

      t.datetime :created_at, null: false

      t.references :eventable, polymorphic: true, null: false, index: true
    end

    add_index :events, [:eventable_type, :eventable_id, :created_at],
      name: 'index_events_on_eventable_and_created_at'
  end
end
```

```bash
bin/rake db:migrate
```

##### b. add model

```ruby
class Event < ActiveRecord::Base
  self.inheritance_column = nil

  attribute :created_at, :datetime, default: -> { Time.current }

  belongs_to :eventable, polymorphic: true

  validates :type, presence: true
  validates :eventable, presence: true
end
```

#### 2. associate events with your existing models

##### a. invoice

```ruby
class Invoice < ActiveRecord::Base
  has_many :events,
            -> { order(created_at: :asc) },
            as: :eventable
end
```

##### b. contact

```ruby
class Contact < ActiveRecord::Base
  has_many :events,
            -> { order(created_at: :asc) },
            as: :eventable
end
```

#### 3. integrate events with outboxer

##### a. generate outboxer schema and publisher

```bash
bin/rails generate outboxer:install
```

##### b. migrate outboxer schema

```bash
bin/rake db:migrate
```

##### c. associate outboxer message with event

```ruby
class Event < ActiveRecord::Base
  # ...

  has_one :outboxer_message,
          class_name: 'Outboxer::Models::Message',
          as: :outboxer_messageable,
          dependent: :destroy

  after_create -> { create_outboxer_message! }
end
```

#### 4. publish events

##### a. update block to queue an event handler worker

```ruby
Outboxer::Message.publish! do |outboxer_messageable|
  case outboxer_messageable.class
  when Event
    EventHandlerWorker.perform_async({ 'id' => outboxer_messageable.id })
  end
end
```

##### b. run the outboxer publisher

```bash
bin/outboxer_publisher
```


## Implementation

To see all the parts working together in a single place, check out the [publisher_spec.rb](https://github.com/fast-programmer/outboxer/blob/master/spec/outboxer/message_spec.rb)


## Motivation

Outboxer was created to help teams transition Ruby on Rails apps to event driven architecture quickly.

Specifically this means:

1. fast integration into existing Ruby on Rails applications (< 1 day)
2. comprehensive documentation
3. high reliability in production environments
4. forever free to use in commerical applications (MIT licence)

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/fast-programmer/outboxer. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/fast-programmer/outboxer/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Outboxer project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/fast-programmer/outboxer/blob/main/CODE_OF_CONDUCT.md).
