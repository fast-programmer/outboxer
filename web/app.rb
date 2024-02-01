require 'bundler/setup'
require 'outboxer'
require 'sinatra/base'
require 'kaminari'
require 'pry-byebug'

environment = ENV['RAILS_ENV'] || 'development'
config = Outboxer::Database.config(environment: environment)
Outboxer::Database.connect!(config: config.merge('pool' => 5))

module Outboxer
  class App < Sinatra::Base
    get '/' do
      page = params[:page] || 1
      limit = params[:limit] || 10
      sort = %w[id status outboxer_messageable_type outboxer_messageable_id created_at updated_at]
        .include?(params[:sort]) ? params[:sort].to_sym : :created_at
      order = %w[asc desc].include?(params[:order]) ? params[:order].to_sym : :asc

      messages = Models::Message.order(sort => order).page(page).per(limit)

      erb :layout, locals: {
        messages: messages,
        page: page,
        limit: limit,
        sort: sort,
        order: order
      }
    end
  end
end

Outboxer::App.run!
