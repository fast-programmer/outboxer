# Outboxer

[![Gem Version](https://badge.fury.io/rb/outboxer.svg)](https://badge.fury.io/rb/outboxer)
![Ruby](https://github.com/fast-programmer/outboxer/actions/workflows/master.yml/badge.svg)

## Background

Outboxer is a Ruby implementation of the [transactional outbox pattern](https://microservices.io/patterns/data/transactional-outbox.html).

## Installation

#### 1. add the outboxer gem to your application's gemfile:

```
gem 'outboxer'
```

#### 2. install the outboxer gem:

```
bundle install
```

## Usage

#### 1. generate the outboxer schema

```bash
bin/rails g outboxer:schema
```

#### 2. migrate the outboxer schema

```bash
bin/rake db:migrate
```

#### 3. add outboxer messageable to the models you want to handle in a sidekiq job

```ruby
class Event < ActiveRecord::Base
  include Outboxer::Messageable

  # your existing code here
end
```

#### 4. generate the sidekiq publisher

```bash
bin/rails g outboxer:publisher:sidekiq
```

#### 5. update the publish block to queue a sidekiq job based on the class of the created model

```ruby
Outboxer::Publisher.publish! do |outboxer_message|
  case outboxer_message.outboxer_messageable_id
  when 'Event'
    EventCreatedJob.perform_async({ 'id' => outboxer_message.outboxer_messageable_id })
  end
end
```

#### 6. run the publisher

```bash
bin/sidekiq_publisher
```

## Motivation

Outboxer was created to help Rails teams migrate to event driven architecture quickly.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/fast-programmer/outboxer. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/fast-programmer/outboxer/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Outboxer project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/fast-programmer/outboxer/blob/main/CODE_OF_CONDUCT.md).
