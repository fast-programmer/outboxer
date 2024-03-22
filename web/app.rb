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
    get '/messages/unpublished' do
      status_counts = Messages.counts_by_status

      sort = params[:sort]|| Messages::SORT
      order = params[:order] || Messages::ORDER
      page = params[:page] || Messages::PAGE
      per_page = params[:per_page] || Messages::PER_PAGE

      messages = Messages.unpublished(sort: sort, order: order, page: page, per_page: per_page)

      erb :messages, locals: {
        status_counts: status_counts,
        messages: messages,
        page: page,
        per_page: per_page,
        sort: sort,
        order: order
      }
    end

    # get '/messages/publishing' do
    # end

    # get '/messages/failed' do
    # end

    post '/messages/update' do
      ids = params[:ids].map(&:to_i)

      case params[:submit]
      when 'Retry Selected'
        Messages.republish_selected!(ids: ids)
      when 'Delete Selected'
        Messages.delete_selected!(ids: ids)
      else
        raise "Unknown value: #{params[:submit]}"
      end

      redirect to('/messages')
    end

    post '/messages/republish_all' do
      ids = params[:ids].map(&:to_i)

      Messages.republish_all!(ids: ids)

      redirect to('/messages')
    end

    post '/messages/delete_all' do
      Messages.delete_all!(batch_size: 100)
    end

    get '/message/:id' do |id|
      messages_count = Models::Message.count

      message = Models::Message.includes(:exceptions).find(id)
      status_counts = { 'unpublished' => 0, 'publishing' => 0, 'failed' => 0 }.merge(
        Models::Message.group(:status).count)

      erb :'messages/show', locals: {
        status_counts: status_counts,
        messages_count: messages_count,
        message: message
      }
    end


    post '/messages/update_per_page' do
      page_number = params[:page_number] || 1
      per_page = [100, 200, 500, 1000].include?(params[:per_page].to_i) ? params[:per_page].to_i : 100
      order = %w[id status messageable created_at updated_at]
        .include?(params[:order]) ? params[:order].to_sym : :created_at
      sort = %w[asc desc].include?(params[:sort]) ? params[:sort].to_sym : :asc

      redirect "/messages?" \
        "#{URI.encode_www_form_component('order')}=#{URI.encode_www_form_component(order)}&" \
        "#{URI.encode_www_form_component('sort')}=#{URI.encode_www_form_component(sort)}&" \
        "#{URI.encode_www_form_component('page')}=#{URI.encode_www_form_component(page)}&" \
        "#{URI.encode_www_form_component('per_page')}=#{URI.encode_www_form_component(per_page)}"
    end

    get '/messages' do
      Messages.list(
        status: params['status'],
        sort: params['sort'],
        order: params['order'],
        page: params['page'].nil? ,
        per_page: params['per_page'])

      status = params['status'] || nil
      sort = params['sort'] || 'created_at'
      order = params['order'] || 'asc'
      page = params['page'] || 1
      per_page = params['per_page'] || 100

      status = params['status'] && params['status'].include?([''])
      per_page = [100, 200, 500, 1000].include?(params[:per_page]) ? params[:per_page] : 100

      sort = ['id', 'status', 'messageable', 'created_at', 'updated_at']
        .include?(sort) ? params['sort'] : 'created_at'

      messages = status.nil? ? User.all : User.where(status: status)

      messages =
        if sort == :messageable
          messages.order(messageable_type: order, messageable_id: order)
        else
          messages.order(sort => order)
        end

      messages = messages.paginate(page: page, per_page: per_page)

      messages
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


    post '/messages/update' do
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

    post '/message/:id/retry' do
      redirect to('/messages')
    end

    post '/message/:id/delete' do
      redirect to('/messages')
    end


    get '/' do
      redirect to('/messages/all')
    end

  end
end

Outboxer::App.run!
