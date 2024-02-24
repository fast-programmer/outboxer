require 'bundler/setup'

require 'outboxer'
require 'sinatra/base'
require 'kaminari'
require 'ransack'
require 'uri'

require 'sinatra/reloader'
require 'pry-byebug'

environment = ENV['RAILS_ENV'] || 'development'
config = Outboxer::Database.config(environment: environment)
Outboxer::Database.connect!(config: config.merge('pool' => 5))

module Outboxer
  class App < Sinatra::Base
    set :method_override, true

    post '/messages/search' do
      text = params['text']

      binding.pry

      redirect to('/messages')
    end

    post '/messages/per_page' do
      page_number = params[:page_number] || 1
      per_page = [100, 200, 500, 1000].include?(params[:per_page].to_i) ? params[:per_page].to_i : 100
      order = %w[id status messageable created_at updated_at]
        .include?(params[:order]) ? params[:order].to_sym : :created_at
      sort = %w[asc desc].include?(params[:sort]) ? params[:sort].to_sym : :asc

      redirect "/messages?" \
        "#{URI.encode_www_form_component('order')}=#{URI.encode_www_form_component(order)}&" \
        "#{URI.encode_www_form_component('sort')}=#{URI.encode_www_form_component(sort)}&" \
        "#{URI.encode_www_form_component('page_number')}=#{URI.encode_www_form_component(page_number)}&" \
        "#{URI.encode_www_form_component('per_page')}=#{URI.encode_www_form_component(per_page)}"
    end

    get '/messages' do
      messages = Models::Message

      page_number = params[:page_number] || 1
      messages = messages.page(page_number)

      per_page = [100, 200, 500, 1000].include?(params[:per_page].to_i) ? params[:per_page].to_i : 100
      messages = messages.per(per_page)

      order = %w[asc desc].include?(params[:order]) ? params[:order].to_sym : :asc

      sort = %w[id status messageable created_at updated_at]
        .include?(params[:sort]) ? params[:sort].to_sym : :created_at

      if sort == :messageable
        messages.order(messageable_type: order, messageable_id: order).to_sql
      else
        messages = messages.order(sort => order)
      end

      messages_count = Models::Message.count

      status_counts = { 'unpublished' => 0, 'publishing' => 0, 'failed' => 0 }.merge(
        Models::Message.group(:status).count)

      erb :messages, layout: nil, locals: {
        status_counts: status_counts,
        messages_count: messages_count,
        messages: messages,
        order: order,
        sort: sort,
        page_number: page_number,
        per_page: per_page
      }
    end

    get '/messages/unpublished' do
      page_number = params[:page_number] || 1
      per_page = [100, 200, 500, 1000].include?(params[:per_page].to_i) ? params[:per_page].to_i : 100
      sort = %w[id status messageable created_at updated_at]
        .include?(params[:sort]) ? params[:sort].to_sym : :created_at
      order = %w[asc desc].include?(params[:order]) ? params[:order].to_sym : :asc

      messages_scope = Models::Message.where(status: 'unpublished')
      messages = messages_scope.order(sort => order).page(page_number).per(per_page)
      messages_count = Models::Message.count

      status_counts = { 'unpublished' => 0, 'publishing' => 0, 'failed' => 0 }.merge(
        Models::Message.group(:status).count)

      erb :messages, layout: nil, locals: {
        status_counts: status_counts,
        messages_count: messages_count,
        messages: messages,
        page_number: page_number,
        per_page: per_page,
        sort: sort,
        order: order
      }
    end

    get '/messages/publishing' do
      page_number = params[:page_number] || 1
      per_page = [100, 200, 500, 1000].include?(params[:per_page].to_i) ? params[:per_page].to_i : 100
      sort = %w[id status messageable created_at updated_at]
        .include?(params[:sort]) ? params[:sort].to_sym : :created_at
      order = %w[asc desc].include?(params[:order]) ? params[:order].to_sym : :asc

      messages_scope = Models::Message.where(status: 'publishing')
      messages = messages_scope.order(sort => order).page(page_number).per(per_page)
      messages_count = Models::Message.count

      status_counts = { 'unpublished' => 0, 'publishing' => 0, 'failed' => 0 }.merge(
        Models::Message.group(:status).count)

      erb :messages, layout: nil, locals: {
        status_counts: status_counts,
        messages_count: messages_count,
        messages: messages,
        page_number: page_number,
        per_page: per_page,
        sort: sort,
        order: order
      }
    end

    get '/messages/failed' do
      page_number = params[:page_number] || 1
      per_page = [100, 200, 500, 1000].include?(params[:per_page]) ? params[:per_page].to_i : 100
      sort = %w[id status messageable created_at updated_at]
        .include?(params[:sort]) ? params[:sort].to_sym : :created_at
      order = %w[asc desc].include?(params[:order]) ? params[:order].to_sym : :asc

      messages_scope = Models::Message.where(status: 'failed')
      messages = messages_scope.order(sort => order).page(page_number).per(per_page)
      messages_count = Models::Message.count

      status_counts = { 'unpublished' => 0, 'publishing' => 0, 'failed' => 0 }.merge(
        Models::Message.group(:status).count)

      erb :messages, layout: nil, locals: {
        status_counts: status_counts,
        messages_count: messages_count,
        messages: messages,
        page_number: page_number,
        per_page: per_page,
        sort: sort,
        order: order
      }
    end


    post '/messages/bulk_action' do
      bulk_action = params['bulk_action']
      message_ids = params['message_ids']

      binding.pry

      case bulk_action
      when 'retry_selected'
        # TODO
      when 'delete_selected'
        # TODO
      else
        raise "#{bulk_action} not supported"
      end

      redirect to('/messages')
    end

    delete '/messages/:id' do
      redirect to('/table')
    end

    patch '/messages/:id/retry' do
      redirect to('/messages')
    end

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
      redirect to('/messages/all')
    end

    # get '/messages/:id' do |id|
    #   messages_count = Models::Message.count

    #   message = Models::Message.includes(:outboxer_exceptions).find(id)
    #   status_counts = { 'unpublished' => 0, 'publishing' => 0, 'failed' => 0 }.merge(
    #     Models::Message.group(:status).count)

    #   erb :'messages/show', locals: {
    #     status_counts: status_counts,
    #     messages_count: messages_count,
    #     message: message
    #   }
    # end

    # get '/:status' do |status|
    #   page = params[:page] || 1
    #   limit = params[:limit] || 100
    #   sort = %w[id status messageable_type messageable_id created_at updated_at]
    #     .include?(params[:sort]) ? params[:sort].to_sym : :created_at
    #   order = %w[asc desc].include?(params[:order]) ? params[:order].to_sym : :asc

    #   messages_scope = status == 'all' ? Models::Message : Models::Message.where(status: status)
    #   messages = messages_scope.order(sort => order).page(page).per(limit)
    #   messages_count = Models::Message.count

    #   status_counts = { 'unpublished' => 0, 'publishing' => 0, 'failed' => 0 }.merge(
    #     Models::Message.group(:status).count)

    #   erb :'messages/index', locals: {
    #     status_counts: status_counts,
    #     messages_count: messages_count,
    #     messages: messages,
    #     page: page,
    #     limit: limit,
    #     sort: sort,
    #     order: order
    #   }
    # end
  end
end

Outboxer::App.run!
