# 📤 Outboxer

[![Gem Version](https://badge.fury.io/rb/outboxer.svg)](https://badge.fury.io/rb/outboxer)
[![Coverage Status](https://coveralls.io/repos/github/fast-programmer/outboxer/badge.svg)](https://coveralls.io/github/fast-programmer/outboxer)
[![Join our Discord](https://img.shields.io/badge/Discord-blue?style=flat&logo=discord&logoColor=white)](https://discord.gg/x6EUehX6vU)

**Outboxer** is a **high-performance, high-reliability implementation** of the [**transactional outbox pattern**](https://docs.aws.amazon.com/prescriptive-guidance/latest/cloud-design-patterns/transactional-outbox.html) for **Ruby on Rails** applications.

By solving the **dual write problem**, Outboxer ensures **reliable, at-least-once delivery** of messages across distributed systems.

# Installation

1. Add the gem to your Gemfile:

    ```ruby
    gem 'outboxer'
    ```

2. Install:

    ```bash
    bundle install
    ```

3. Generate schema, publisher, and test scaffolding:

    ```bash
    bin/rails g outboxer:install
    ```

4. Migrate the database:

    ```bash
    bin/rails db:migrate
    ```

# Usage

## 1. Queue an outboxer message after model creation

Add an `after_create` callback to your `Event` model:

    ```ruby
    # app/models/event.rb

    class Event < ApplicationRecord
      after_create { Outboxer::Message.queue(messageable: self) }
    end
    ```

**Note:** This ensures the outboxer messageable is created within the **same transaction** as your model.

#### Example ActiveRecord logs:

    ```sql
    BEGIN
    INSERT INTO "events" ...
    INSERT INTO "outboxer_messages" ...
    COMMIT
    ```

As shown, both the `Event` and the `Outboxer::Message` are committed atomically together.

## 2. Publish queued outboxer messages

Refer to the generated `bin/outboxer_publisher`:

    ```ruby
    # bin/outboxer_publisher

    require "outboxer"

    Outboxer::Publisher.publish_message do |message|
      # TODO: publish message here
    end
    ```

# Management UI

Outboxer ships with a simple web interface to monitor publishers and messages.

## Rails Mounting

    ```ruby
    # config/routes.rb

    require 'outboxer/web'

    Rails.application.routes.draw do
      mount Outboxer::Web, at: '/outboxer'
    end
    ```

## Rack Mounting

    ```ruby
    # config.ru

    require 'outboxer/web'

    map '/outboxer' do
      run Outboxer::Web
    end
    ```

# Contributing

Help us make Outboxer better!

- ⭐ [Star the repo](https://github.com/fast-programmer/outboxer)
- 📮 [Open issues](https://github.com/fast-programmer/outboxer/issues)
- 💬 [Join our Discord](https://discord.gg/x6EUehX6vU)

All contributions are welcome!

# License

This project is open-sourced under the  
[GNU Lesser General Public License v3.0](https://www.gnu.org/licenses/lgpl-3.0.html).
