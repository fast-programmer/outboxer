require 'bundler/setup'

require 'outboxer'
require 'sinatra/base'
require 'kaminari'
require 'uri'
require 'rack/flash'

require 'pry-byebug'

environment = ENV['APP_ENV'] || 'development'
config = Outboxer::Database.config(environment: environment, pool: 5)
Outboxer::Database.connect(config: config)

module Outboxer
  class Web < Sinatra::Base
    use Rack::Flash
    set :views, File.expand_path('../web/views', __FILE__)
    set :public_folder, File.expand_path('../web/public', __FILE__)
    set :show_exceptions, false

    helpers do
      def outboxer_path(path)
        "#{request.script_name}#{path}"
      end
    end

    error StandardError do
      error = env['sinatra.error']
      status 500

      puts "Error: #{error.class.name} - #{error.message}"

      erb :error, locals: { error: error }, layout: false
    end

    get '/' do
      denormalised_query_params = denormalise_query_params(
        status: params[:status],
        sort: params[:sort],
        order: params[:order],
        page: params[:page],
        per_page: params[:per_page],
        time_zone: params[:time_zone])

      normalised_query_params = normalise_query_params(
        status: denormalised_query_params[:status],
        sort: denormalised_query_params[:sort],
        order: denormalised_query_params[:order],
        page: denormalised_query_params[:page],
        per_page: denormalised_query_params[:per_page],
        time_zone: denormalised_query_params[:time_zone])

      normalised_query_string = normalise_query_string(
        status: denormalised_query_params[:status],
        sort: denormalised_query_params[:sort],
        order: denormalised_query_params[:order],
        page: denormalised_query_params[:page],
        per_page: denormalised_query_params[:per_page],
        time_zone: denormalised_query_params[:time_zone])

      messages_metrics = Messages.metrics

      erb :home, locals: {
        messages_metrics: messages_metrics,
        denormalised_query_params: denormalised_query_params,
        normalised_query_params: normalised_query_params,
        normalised_query_string: normalised_query_string
      }
    end

    post '/update_time_zone' do
      denormalised_query_params = denormalise_query_params(
        status: params[:status],
        sort: params[:sort],
        order: params[:order],
        page: params[:page],
        per_page: params[:per_page],
        time_zone: params[:time_zone])

      normalised_query_string = normalise_query_string(
        status: denormalised_query_params[:status],
        sort: denormalised_query_params[:sort],
        order: denormalised_query_params[:order],
        page: denormalised_query_params[:page],
        per_page: denormalised_query_params[:per_page],
        time_zone: denormalised_query_params[:time_zone])

      redirect to("/messages#{normalised_query_string}")
    end

    get '/messages' do
      denormalised_query_params = denormalise_query_params(
        status: params[:status],
        sort: params[:sort],
        order: params[:order],
        page: params[:page],
        per_page: params[:per_page],
        time_zone: params[:time_zone])

      normalised_query_params = normalise_query_params(
        status: denormalised_query_params[:status],
        sort: denormalised_query_params[:sort],
        order: denormalised_query_params[:order],
        page: denormalised_query_params[:page],
        per_page: denormalised_query_params[:per_page],
        time_zone: denormalised_query_params[:time_zone])

      normalised_query_string = normalise_query_string(
        status: denormalised_query_params[:status],
        sort: denormalised_query_params[:sort],
        order: denormalised_query_params[:order],
        page: denormalised_query_params[:page],
        per_page: denormalised_query_params[:per_page],
        time_zone: denormalised_query_params[:time_zone])

      messages_metrics = Messages.metrics

      paginated_messages = Messages.list(
        status: denormalised_query_params[:status],
        sort: denormalised_query_params[:sort],
        order: denormalised_query_params[:order],
        page: denormalised_query_params[:page]&.to_i,
        per_page: denormalised_query_params[:per_page]&.to_i,
        time_zone: denormalised_query_params[:time_zone])

      pagination = generate_pagination(
        current_page: paginated_messages[:current_page],
        total_pages: paginated_messages[:total_pages],
        denormalised_query_params: denormalised_query_params)

      erb :messages, locals: {
        messages_metrics: messages_metrics,
        messages: paginated_messages[:messages],
        denormalised_query_params: denormalised_query_params,
        normalised_query_params: normalised_query_params,
        normalised_query_string: normalised_query_string,
        headers: generate_headers(denormalised_query_params: denormalised_query_params),
        pagination: pagination
      }
    end

    HEADERS = {
      id: 'Id',
      status: 'Status',
      messageable: 'Messageable',
      created_at: 'Created At',
      updated_at: 'Updated At',
      updated_by: 'Updated By',
    }

    def generate_pagination(current_page:, total_pages:, denormalised_query_params:)
      previous_page = nil
      pages = []
      next_page = nil

      if current_page > 1
        previous_page = {
          text: 'Previous',
          href: outboxer_path("/messages" + normalise_query_string(
            status: denormalised_query_params[:status],
            sort: denormalised_query_params[:sort],
            order: denormalised_query_params[:order],
            page: current_page - 1,
            per_page: denormalised_query_params[:per_page],
            time_zone: denormalised_query_params[:time_zone]))
        }
      end

      pages = (([current_page - 4, 1].max)..([current_page + 4, total_pages].min)).map do |page|
        {
          text: page,
          href: outboxer_path("/messages" + normalise_query_string(
            status: denormalised_query_params[:status],
            sort: denormalised_query_params[:sort],
            order: denormalised_query_params[:order],
            page: page,
            per_page: denormalised_query_params[:per_page],
            time_zone: denormalised_query_params[:time_zone])),
          is_active: current_page == page
        }
      end

      if current_page < total_pages
        next_page = {
          text: 'Next',
          href: outboxer_path("/messages" + normalise_query_string(
            status: denormalised_query_params[:status],
            sort: denormalised_query_params[:sort],
            order: denormalised_query_params[:order],
            page: current_page + 1,
            per_page: denormalised_query_params[:per_page],
            time_zone: denormalised_query_params[:time_zone]))
        }
      end

      { previous_page: previous_page, pages: pages, next_page: next_page }
    end

    def generate_headers(denormalised_query_params:)
      HEADERS.map do |header_key, header_text|
        if denormalised_query_params[:sort] == header_key
          if denormalised_query_params[:order] == :asc
            {
              text: header_text,
              icon_class: 'bi bi-arrow-up',
              href: outboxer_path('/messages' + normalise_query_string(
                status: denormalised_query_params[:status],
                order: :desc,
                sort: header_key,
                page: 1,
                per_page: denormalised_query_params[:per_page],
                time_zone: denormalised_query_params[:time_zone]
              ))
            }
          else
            {
              text: header_text,
              icon_class: 'bi bi-arrow-down',
              href: outboxer_path('/messages' + normalise_query_string(
                status: denormalised_query_params[:status],
                order: :asc,
                sort: header_key,
                page: 1,
                per_page: denormalised_query_params[:per_page],
                time_zone: denormalised_query_params[:time_zone]
              ))
            }
          end
        else
          {
            text: header_text,
            icon_class: '',
            href: outboxer_path('/messages' + normalise_query_string(
              status: denormalised_query_params[:status],
              order: :asc,
              sort: header_key,
              page: 1,
              per_page: denormalised_query_params[:per_page],
              time_zone: denormalised_query_params[:time_zone]
            ))
          }
        end
      end
    end

    def denormalise_query_params(status: Messages::LIST_STATUS_DEFAULT,
                                 sort: Messages::LIST_SORT_DEFAULT,
                                 order: Messages::LIST_ORDER_DEFAULT,
                                 page: Messages::LIST_PAGE_DEFAULT,
                                 per_page: Messages::LIST_PER_PAGE_DEFAULT,
                                 time_zone: Messages::LIST_TIME_ZONE_DEFAULT)
      {
        status: status&.to_sym || Messages::LIST_STATUS_DEFAULT,
        sort: sort&.to_sym || Messages::LIST_SORT_DEFAULT,
        order: order&.to_sym || Messages::LIST_ORDER_DEFAULT,
        page: page&.to_i || Messages::LIST_PAGE_DEFAULT,
        per_page: per_page&.to_i || Messages::LIST_PER_PAGE_DEFAULT,
        time_zone: time_zone&.to_s || Messages::LIST_TIME_ZONE_DEFAULT,
      }
    end

    def normalise_query_params(status: Messages::LIST_STATUS_DEFAULT,
                               sort: Messages::LIST_SORT_DEFAULT,
                               order: Messages::LIST_ORDER_DEFAULT,
                               page: Messages::LIST_PAGE_DEFAULT,
                               per_page: Messages::LIST_PER_PAGE_DEFAULT,
                               time_zone: Messages::LIST_TIME_ZONE_DEFAULT)
      {
        status: status == Messages::LIST_STATUS_DEFAULT ? nil : status,
        sort: sort == Messages::LIST_SORT_DEFAULT ? nil : sort,
        order: order == Messages::LIST_ORDER_DEFAULT ? nil : order,
        page: page.to_i == Messages::LIST_PAGE_DEFAULT ? nil : page,
        per_page: per_page.to_i == Messages::LIST_PER_PAGE_DEFAULT ? nil : per_page,
        time_zone: time_zone.to_s == Messages::LIST_TIME_ZONE_DEFAULT ? nil : time_zone
      }.compact
    end

    def normalise_query_string(status: Messages::LIST_STATUS_DEFAULT,
                               sort: Messages::LIST_SORT_DEFAULT,
                               order: Messages::LIST_ORDER_DEFAULT,
                               page: Messages::LIST_PAGE_DEFAULT,
                               per_page: Messages::LIST_PER_PAGE_DEFAULT,
                               time_zone: Messages::LIST_TIME_ZONE_DEFAULT)
      normalised_query_params = normalise_query_params(
        status: status,
        sort: sort,
        order: order,
        page: page,
        per_page: per_page,
        time_zone: time_zone)

      normalised_query_params.empty? ? '' : "?#{URI.encode_www_form(normalised_query_params)}"
    end

    post '/messages/update' do
      denormalised_query_params = denormalise_query_params(
        status: params[:status],
        sort: params[:sort],
        order: params[:order],
        page: params[:page],
        per_page: params[:per_page],
        time_zone: params[:time_zone])

      normalised_query_string = normalise_query_string(
        status: denormalised_query_params[:status],
        sort: denormalised_query_params[:sort],
        order: denormalised_query_params[:order],
        page: denormalised_query_params[:page],
        per_page: denormalised_query_params[:per_page],
        time_zone: denormalised_query_params[:time_zone])

      ids = params[:selected_ids].map(&:to_i)

      result = case params[:action]
      when 'requeue_by_ids'
        result = Messages.requeue_by_ids(ids: ids)

        message_text = result[:requeued_count] == 1 ? 'message' : 'messages'

        if result[:requeued_count] > 0
          flash[:primary] = "Requeued #{result[:requeued_count]} #{message_text}"
        end

        unless result[:not_requeued_ids].empty?
          flash[:warning] = "Could not requeue #{message_text} with ids " +
            "#{result[:not_requeued_ids].join(', ')}"
        end

        result
      when 'delete_by_ids'
        result = Messages.delete_by_ids(ids: ids)

        message_text = result[:deleted_count] == 1 ? 'message' : 'messages'

        if result[:deleted_count] > 0
          flash[:primary] = "Deleted #{result[:deleted_count]} #{message_text}"
        end

        unless result[:not_deleted_ids].empty?
          flash[:warning] = "Could not delete #{message_text} with ids " +
            "#{result[:not_deleted_ids].join(', ')}"
        end

        result
      else
        raise "Unknown action: #{params[:action]}"
      end

      redirect to("/messages#{normalised_query_string}")
    end

    post '/messages/requeue_all' do
      denormalised_query_params = denormalise_query_params(
        status: params[:status],
        sort: params[:sort],
        order: params[:order],
        page: params[:page],
        per_page: params[:per_page],
        time_zone: params[:time_zone])

      normalised_query_string = normalise_query_string(
        status: denormalised_query_params[:status],
        sort: denormalised_query_params[:sort],
        order: denormalised_query_params[:order],
        page: denormalised_query_params[:page],
        per_page: denormalised_query_params[:per_page],
        time_zone: denormalised_query_params[:time_zone])

      result = Messages.requeue_all(
        status: denormalised_query_params[:status], older_than: Time.now.utc)

      message_text = result[:requeued_count] == 1 ? 'message' : 'messages'
      flash[:primary] = "#{result[:requeued_count]} #{message_text} have been queued"

      redirect to("/messages#{normalised_query_string}")
    end

    post '/messages/delete_all' do
      denormalised_query_params = denormalise_query_params(
        status: params[:status],
        sort: params[:sort],
        order: params[:order],
        page: params[:page],
        per_page: params[:per_page],
        time_zone: params[:time_zone])

      normalised_query_string = normalise_query_string(
        status: denormalised_query_params[:status],
        sort: denormalised_query_params[:sort],
        order: denormalised_query_params[:order],
        page: denormalised_query_params[:page],
        per_page: denormalised_query_params[:per_page],
        time_zone: denormalised_query_params[:time_zone])

      result = Messages.delete_all(
        status: denormalised_query_params[:status], older_than: Time.now.utc)

      message_text = result[:deleted_count] == 1 ? 'message' : 'messages'
      flash[:primary] = "#{result[:deleted_count]} #{message_text} have been deleted"

      redirect to("/messages#{normalised_query_string}")
    end

    post '/messages/update_per_page' do
      denormalised_query_params = denormalise_query_params(
        status: params[:status],
        sort: params[:sort],
        order: params[:order],
        page: params[:page],
        per_page: params[:per_page],
        time_zone: params[:time_zone])

      normalised_query_string = normalise_query_string(
        status: denormalised_query_params[:status],
        sort: denormalised_query_params[:sort],
        order: denormalised_query_params[:order],
        page: denormalised_query_params[:page],
        per_page: denormalised_query_params[:per_page],
        time_zone: denormalised_query_params[:time_zone])

      redirect to("/messages#{normalised_query_string}")
    end

    get '/message/:id' do
      denormalised_query_params = denormalise_query_params(
        status: params[:status],
        sort: params[:sort],
        order: params[:order],
        page: params[:page],
        per_page: params[:per_page],
        time_zone: params[:time_zone])

      normalised_query_params = normalise_query_params(
        status: denormalised_query_params[:status],
        sort: denormalised_query_params[:sort],
        order: denormalised_query_params[:order],
        page: denormalised_query_params[:page],
        per_page: denormalised_query_params[:per_page],
        time_zone: denormalised_query_params[:time_zone])

      messages_metrics = Messages.metrics

      message = Message.find_by_id(id: params[:id])

      erb :message, locals: {
        denormalised_query_params: denormalised_query_params,
        normalised_query_params: normalised_query_params,
        messages_metrics: messages_metrics,
        message: message
      }
    end

    post '/message/:id/requeue' do
      denormalised_query_params = denormalise_query_params(
        status: params[:status],
        sort: params[:sort],
        order: params[:order],
        page: params[:page],
        per_page: params[:per_page],
        time_zone: params[:time_zone])

      normalised_query_string = normalise_query_string(
        status: denormalised_query_params[:status],
        sort: denormalised_query_params[:sort],
        order: denormalised_query_params[:order],
        page: denormalised_query_params[:page],
        per_page: denormalised_query_params[:per_page],
        time_zone: denormalised_query_params[:time_zone])

      Message.requeue(id: params[:id])

      flash[:primary] = "Message #{params[:id]} was queued"

      redirect to("/messages#{normalised_query_string}")
    end

    post '/message/:id/delete' do
      denormalised_query_params = denormalise_query_params(
        status: params[:status],
        sort: params[:sort],
        order: params[:order],
        page: params[:page],
        per_page: params[:per_page],
        time_zone: params[:time_zone])

      normalised_query_string = normalise_query_string(
        status: denormalised_query_params[:status],
        sort: denormalised_query_params[:sort],
        order: denormalised_query_params[:order],
        page: denormalised_query_params[:page],
        per_page: denormalised_query_params[:per_page],
        time_zone: denormalised_query_params[:time_zone])

      Message.delete(id: params[:id])

      flash[:primary] = "Message #{params[:id]} was deleted"

      redirect to("/messages#{normalised_query_string}")
    end

    get '/message/:id/messageable' do
      denormalised_query_params = denormalise_query_params(
        status: params[:status],
        sort: params[:sort],
        order: params[:order],
        page: params[:page],
        per_page: params[:per_page],
        time_zone: params[:time_zone])

      message = Message.find_by_id(id: params[:id])
      messages_metrics = Messages.metrics

      messageable_class = Object.const_get("#{message[:messageable_type]}")
      messageable = messageable_class.find(message[:messageable_id])

      erb :messageable, locals: {
        message: message,
        messageable: messageable,
        messages_metrics: messages_metrics,
        denormalised_query_params: denormalised_query_params
      }
    end
  end
end
