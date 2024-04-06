require 'bundler/setup'

require 'outboxer'
require 'sinatra/base'
require 'kaminari'
require 'uri'
require 'rack/flash'

require 'sinatra/reloader'
require 'pry-byebug'

environment = ENV['RAILS_ENV'] || 'development'
config = Outboxer::Database.config(environment: environment)
Outboxer::Database.connect(config: config.merge('pool' => 5))

module Outboxer
  class App < Sinatra::Base
    enable :sessions
    use Rack::Flash

    get '/messages' do
      message_status_counts = Messages.counts_by_status

      messages_publishing = Messages.publishing(
        sort: :updated_at, order: :asc, page: 1, per_page: 100)

      messages_queued = Messages.queued(
        sort: :updated_at, order: :asc, page: 1, per_page: 100)

      messages_backlogged = Messages.backlogged(
        sort: :updated_at, order: :asc, page: 1, per_page: 100)

      erb :home, locals: {
        message_status_counts: message_status_counts,
        messages_publishing: messages_publishing,
        messages_queued: messages_queued,
        messages_backlogged: messages_backlogged
      }
    end

    get '/' do
      redirect to('/messages/all')
    end

    get '/messages/all' do
      message_status_counts = Messages.counts_by_status

      sort = params[:sort] || Messages::SORT
      order = params[:order] || Messages::ORDER
      page = params[:page]&.to_i || Messages::PAGE
      per_page = params[:per_page]&.to_i || Messages::PER_PAGE

      messages = Messages.list(sort: sort, order: order, page: page, per_page: per_page)

      erb :messages, locals: {
        message_status_counts: message_status_counts,
        messages: messages,
        page: page,
        per_page: per_page,
        sort: sort,
        order: order
      }
    end

    get '/messages/backlogged' do
      message_status_counts = Messages.counts_by_status

      sort = params[:sort]|| Messages::SORT
      order = params[:order] || Messages::ORDER
      page = params[:page] || Messages::PAGE
      per_page = params[:per_page] || Messages::PER_PAGE

      messages = Messages.backlogged(sort: sort, order: order, page: page, per_page: per_page)

      erb :messages, locals: {
        message_status_counts: message_status_counts,
        messages: messages,
        page: page,
        per_page: per_page,
        sort: sort,
        order: order
      }
    end

    get '/messages/queued' do
      message_status_counts = Messages.counts_by_status

      sort = params[:sort]|| Messages::SORT
      order = params[:order] || Messages::ORDER
      page = params[:page] || Messages::PAGE
      per_page = params[:per_page] || Messages::PER_PAGE

      messages = Messages.queued(sort: sort, order: order, page: page, per_page: per_page)

      erb :messages, locals: {
        message_status_counts: message_status_counts,
        messages: messages,
        page: page,
        per_page: per_page,
        sort: sort,
        order: order
      }
    end

    get '/messages/publishing' do
      message_status_counts = Messages.counts_by_status

      sort = params[:sort]|| Messages::SORT
      order = params[:order] || Messages::ORDER
      page = params[:page] || Messages::PAGE
      per_page = params[:per_page] || Messages::PER_PAGE

      messages = Messages.publishing(sort: sort, order: order, page: page, per_page: per_page)

      erb :messages, locals: {
        message_status_counts: message_status_counts,
        messages: messages,
        page: page,
        per_page: per_page,
        sort: sort,
        order: order
      }
    end

    get '/messages/failed' do
      message_status_counts = Messages.counts_by_status

      sort = params[:sort]|| Messages::SORT
      order = params[:order] || Messages::ORDER
      page = params[:page] || Messages::PAGE
      per_page = params[:per_page] || Messages::PER_PAGE

      messages = Messages.failed(sort: sort, order: order, page: page, per_page: per_page)

      erb :messages, locals: {
        message_status_counts: message_status_counts,
        messages: messages,
        page: page,
        per_page: per_page,
        sort: sort,
        order: order
      }
    end

    post '/messages/update' do
      ids = params[:ids].map(&:to_i)

      result = case params[:submit]
      when 'Republish Selected'
        Messages.republish_selected!(ids: ids)
      when 'Delete Selected'
        Messages.delete_selected!(ids: ids)
      else
        raise "Unknown value: #{params[:submit]}"
      end

      flash[:notice] = "#{result['count']} messages have been updated."

      redirect to('/messages/all')
    end

    post '/messages/republish_all' do
      result = Messages.republish_all!

      flash[:notice] = "#{result['count']} messages have been republished."

      redirect to('/messages/all')
    end

    post '/messages/delete_all' do
      result = Messages.delete_all!(batch_size: 100)

      flash[:notice] = "#{result['count']} messages have been deleted."

      redirect to('/messages/all')
    end

    post '/messages/per_page' do
      params_hash = {
        'order' => params[:order],
        'sort' => params[:sort],
        'page' => params[:page],
        'per_page' => params[:per_page]
      }

      filtered_params = params_hash.reject { |_, value| value.nil? || value.strip.empty? }

      query_string = URI.encode_www_form(filtered_params)

      redirect "/messages/all?#{query_string}"
    end

    get '/message/:id' do
      message_status_counts = Messages.counts_by_status

      message = Message.find_by_id!(id: params[:id].to_i)

      halt 404, "Message not found" unless message

      erb :message, locals: {
        message_status_counts: message_status_counts,
        message: message
      }
    end

    post '/message/:id/republish' do
      Message.republish!(id: params[:id])

      flash[:notice] = "message #{params[:id]} was republished."

      redirect to('/messages/all')
    end

    post '/message/:id/delete' do
      Message.delete!(id: params[:id])

      flash[:notice] = "message #{params[:id]} was deleted."

      redirect to('/messages/all')
    end
  end
end

Outboxer::App.run!

# bundle exec rerun 'ruby web/app.rb'
