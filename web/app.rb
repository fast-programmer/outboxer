require 'bundler/setup'

require 'outboxer'
require 'sinatra/base'
require 'kaminari'
require 'ransack'

require 'pry-byebug'

environment = ENV['RAILS_ENV'] || 'development'
config = Outboxer::Database.config(environment: environment)
Outboxer::Database.connect!(config: config.merge('pool' => 5))

module Outboxer
  class App < Sinatra::Base
    get '/searches' do
      q = Outboxer::Models::Message.ransack(params[:q])
      messages = q.result.includes(:outboxer_exceptions)

      erb :'searches/new',
        locals: { q: q, messages: messages },
        layout: nil
    end

    post '/searches' do
      q = Outboxer::Models::Message.ransack(params[:q])
      # messages = q.result.includes(:outboxer_exceptions)

      query_string = URI.encode_www_form(params[:q].to_h)

      redirect to("/searches?q=#{query_string}")

      # erb :'searches/new',
      #   locals: { q: q, messages: messages },
      #   layout: nil
    end

    get '/' do
      redirect to('/all')
    end

    get '/messages/:id' do |id|
      messages_count = Models::Message.count

      message = Models::Message.includes(:outboxer_exceptions).find(id)
      status_counts = { 'unpublished' => 0, 'publishing' => 0, 'failed' => 0 }.merge(
        Models::Message.group(:status).count)

      erb :'messages/show', locals: {
        status_counts: status_counts,
        messages_count: messages_count,
        message: message
      }
    end

    get '/:status' do |status|
      page = params[:page] || 1
      limit = params[:limit] || 100
      sort = %w[id status messageable_type messageable_id created_at updated_at]
        .include?(params[:sort]) ? params[:sort].to_sym : :created_at
      order = %w[asc desc].include?(params[:order]) ? params[:order].to_sym : :asc

      messages_scope = status == 'all' ? Models::Message : Models::Message.where(status: status)
      messages = messages_scope.order(sort => order).page(page).per(limit)
      messages_count = Models::Message.count

      status_counts = { 'unpublished' => 0, 'publishing' => 0, 'failed' => 0 }.merge(
        Models::Message.group(:status).count)

      erb :'messages/index', locals: {
        status_counts: status_counts,
        messages_count: messages_count,
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
