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

    get '/' do
      denormalised_params = denormalise_params(
        status: params[:status],
        sort: params[:sort],
        order: params[:order],
        page: params[:page]&.to_i,
        per_page: params[:per_page]&.to_i)

      message_status_counts = Messages.counts_by_status

      messages_publishing = Messages.paginate(
        status: 'publishing', sort: 'updated_at', order: 'asc', page: 1, per_page: 100)

      messages_queued = Messages.paginate(
        status: 'queued', sort: 'updated_at', order: 'asc', page: 1, per_page: 100)

      messages_backlogged = Messages.paginate(
        status: 'backlogged', sort: 'updated_at', order: 'asc', page: 1, per_page: 100)

      erb :home, locals: {
        denormalised_params: denormalised_params,
        message_status_counts: message_status_counts,
        messages_publishing: messages_publishing,
        messages_queued: messages_queued,
        messages_backlogged: messages_backlogged
      }
    end

    get '/messages' do
      message_status_counts = Messages.counts_by_status

      denormalised_params = denormalise_params(
        status: params[:status],
        sort: params[:sort],
        order: params[:order],
        page: params[:page]&.to_i,
        per_page: params[:per_page]&.to_i)

      normalised_params = normalise_params(
        status: denormalised_params[:status],
        sort: denormalised_params[:sort],
        order: denormalised_params[:order],
        page: denormalised_params[:page]&.to_i,
        per_page: denormalised_params[:per_page]&.to_i)

      paginated_messages = Messages.paginate(
        status: denormalised_params[:status],
          sort: denormalised_params[:sort],
          order: denormalised_params[:order],
          page: denormalised_params[:page]&.to_i,
          per_page: denormalised_params[:per_page]&.to_i)

      pagination = generate_pagination(
        current_page: paginated_messages[:current_page],
        total_pages: paginated_messages[:total_pages],
        params: denormalised_params)

      erb :messages, locals: {
        message_status_counts: message_status_counts,
        messages: paginated_messages[:messages],
        headers: generate_headers(params: denormalised_params),
        pagination: pagination,
        denormalised_params: denormalised_params,
        normalised_params: normalised_params,
        per_page: params[:per_page]&.to_i || Messages::DEFAULT_PER_PAGE
      }
    end

    HEADERS = {
      'id' => 'Id',
      'status' => 'Status',
      'messageable' => 'Messageable',
      'created_at' => 'Created At',
      'updated_at' => 'Updated At'
    }

    def generate_pagination(current_page:, total_pages:, params:)
      previous_page = nil
      pages = []
      next_page = nil

      if current_page > 1
        previous_page = {
          text: 'Previous',
          href: "/messages" + normalise_params(
            status: params[:status], sort: params[:sort], order: params[:order],
            page: current_page - 1, per_page: params[:per_page])
        }
      end

      pages = (([current_page - 4, 1].max)..([current_page + 4, total_pages].min)).map do |page|
        {
          text: page,
          href: "/messages" + normalise_params(
            status: params[:status], sort: params[:sort], order: params[:order], page: page,
            per_page: params[:per_page]),
          is_active: current_page == page
        }
      end

      if current_page < total_pages
        next_page = {
          text: 'Next',
          href: "/messages" + normalise_params(
            status: params[:status], sort: params[:sort], order: params[:order],
            page: current_page + 1, per_page: params[:per_page])
        }
      end

      { previous_page: previous_page, pages: pages, next_page: next_page }
    end

    def generate_headers(params:)
      HEADERS.map do |header_key, header_text|
        if params[:sort] == header_key
          if params[:order] == 'asc'
            {
              text: header_text,
              icon_class: 'bi bi-arrow-up',
              href: 'messages' + normalise_params(
                status: params[:status],
                order: 'desc',
                sort: header_key,
                page: 1,
                per_page: params[:per_page]
              )
            }
          else
            {
              text: header_text,
              icon_class: 'bi bi-arrow-down',
              href: 'messages' + normalise_params(
                status: params[:status],
                order: 'asc',
                sort: header_key,
                page: 1,
                per_page: params[:per_page]
              )
            }
          end
        else
          {
            text: header_text,
            icon_class: '',
            href: 'messages' + normalise_params(
              status: params[:status],
              order: 'asc',
              sort: header_key,
              page: 1,
              per_page: params[:per_page]
            )
          }
        end
      end
    end

    def denormalise_params(status: Messages::DEFAULT_STATUS,
                           sort: Messages::DEFAULT_SORT,
                           order: Messages::DEFAULT_ORDER,
                           page: Messages::DEFAULT_PAGE,
                           per_page: Messages::DEFAULT_PER_PAGE)
      {
        status: params[:status] || Messages::DEFAULT_STATUS,
        sort: params[:sort] || Messages::DEFAULT_SORT,
        order: params[:order] || Messages::DEFAULT_ORDER,
        page: params[:page]&.to_i || Messages::DEFAULT_PAGE,
        per_page: params[:per_page]&.to_i || Messages::DEFAULT_PER_PAGE
      }
    end

    def normalise_params(status: Messages::DEFAULT_STATUS,
                         sort: Messages::DEFAULT_SORT,
                         order: Messages::DEFAULT_ORDER,
                         page: Messages::DEFAULT_PAGE,
                         per_page: Messages::DEFAULT_PER_PAGE)
      normalised_params = {
        status: status == Messages::DEFAULT_STATUS ? nil : status,
        sort: sort == Messages::DEFAULT_SORT ? nil : sort,
        order: order == Messages::DEFAULT_ORDER ? nil : order,
        page: page == Messages::DEFAULT_PAGE ? nil : page,
        per_page: per_page == Messages::DEFAULT_PER_PAGE ? nil : per_page
      }.compact

      normalised_params.empty? ? '' : "?#{URI.encode_www_form(normalised_params)}"
    end

    post '/messages/update' do
      ids = params[:selected_ids].map(&:to_i)

      result = case params[:action]
      when 'republish_selected'
        result = Messages.republish_selected(ids: ids)

        if result[:republished_count] > 0
          flash[:primary] = "Republished #{result[:republished_count]} messages"
        end

        unless result[:not_republished_ids].empty?
          flash[:warning] = "Could not republish messages with ids " +
            "#{result[:not_republished_ids].join(', ')}"
        end

        result
      when 'delete_selected'
        result = Messages.delete_selected(ids: ids)

        if result[:deleted_count] > 0
          flash[:primary] = "Deleted #{result[:deleted_count]} messages"
        end

        unless result[:not_deleted_ids].empty?
          flash[:warning] = "Could not delete messages with ids " +
            "#{result[:not_deleted_ids].join(', ')}"
        end

        result
      else
        raise "Unknown action: #{params[:action]}"
      end

      redirect to('/messages')
    end

    post '/messages/republish_all' do
      denormalised_params = denormalise_params(
        status: params[:status],
        sort: params[:sort],
        order: params[:order],
        page: params[:page]&.to_i,
        per_page: params[:per_page]&.to_i)

      result = Messages.republish_all(status: denormalised_params[:status])

      flash[:primary] = "#{result[:republished_count]} messages have been republished"

      redirect to('/messages')
    end

    post '/messages/delete_all' do
      denormalised_params = denormalise_params(
        status: params[:status],
        sort: params[:sort],
        order: params[:order],
        page: params[:page]&.to_i,
        per_page: params[:per_page]&.to_i)

      result = Messages.delete_all(status: denormalised_params[:status])

      flash[:primary] = "#{result[:deleted_count]} messages have been deleted"

      redirect to('/messages')
    end

    post '/messages/update_per_page' do
      denormalised_params = denormalise_params(
        status: params[:status],
        sort: params[:sort],
        order: params[:order],
        page: params[:page]&.to_i,
        per_page: params[:per_page]&.to_i)

      normalised_params = normalise_params(
        status: denormalised_params[:status],
        sort: denormalised_params[:sort],
        order: denormalised_params[:order],
        page: denormalised_params[:page],
        per_page: denormalised_params[:per_page])

      redirect "/messages#{normalised_params}"
    end

    get '/message/:id' do
      message_status_counts = Messages.counts_by_status

      message = Message.find_by_id(id: params[:id].to_i)

      halt 404, "Message not found" unless message

      erb :message, locals: {
        message_status_counts: message_status_counts,
        message: message
      }
    end

    post '/message/:id/republish' do
      Message.republish(id: params[:id])

      flash[:primary] = "Message #{params[:id]} was republished"

      redirect to('/messages')
    end

    post '/message/:id/delete' do
      Message.delete(id: params[:id])

      flash[:primary] = "Message #{params[:id]} was deleted"

      redirect to('/messages')
    end
  end
end

Outboxer::App.run!

# bundle exec rerun 'ruby web/app.rb'
