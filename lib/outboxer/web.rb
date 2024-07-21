require 'bundler/setup'

require 'outboxer'
require 'sinatra/base'
require 'kaminari'
require 'uri'
require 'rack/flash'

require 'pry-byebug'

environment = ENV['RAILS_ENV'] || 'development'
config = Outboxer::Database.config(environment: environment)
Outboxer::Database.connect(config: config.merge('pool' => 5))

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
      denormalised_params = denormalise_params(
        status: nil,
        sort: :updated_at,
        order: :asc,
        page: 1,
        per_page: params[:per_page]&.to_i)

      message_status_counts = Messages.counts_by_status

      messages_publishing = Messages.list(
        status: :publishing,
        sort: :updated_at,
        order: :asc,
        page: 1,
        per_page: denormalised_params[:per_page])

      messages_publishing_link = outboxer_path('/messages' + normalise_params(
        status: :publishing,
        sort: denormalised_params[:sort],
        order: denormalised_params[:order],
        page: denormalised_params[:page],
        per_page: denormalised_params[:per_page]))

      messages_dequeued = Messages.list(
        status: :dequeued,
        sort: :updated_at,
        order: :asc,
        page: 1,
        per_page: denormalised_params[:per_page])

      messages_dequeued_link = outboxer_path('/messages' + normalise_params(
        status: :dequeued,
        sort: denormalised_params[:sort],
        order: denormalised_params[:order],
        page: denormalised_params[:page],
        per_page: denormalised_params[:per_page]))

      messages_queued = Messages.list(
        status: :queued,
        sort: :updated_at,
        order: :asc,
        page: 1,
        per_page: denormalised_params[:per_page])

      messages_queued_link = outboxer_path('/messages' + normalise_params(
        status: :queued,
        sort: denormalised_params[:sort],
        order: denormalised_params[:order],
        page: denormalised_params[:page],
        per_page: denormalised_params[:per_page]))

      erb :home, locals: {
        denormalised_params: denormalised_params,
        message_status_counts: message_status_counts,
        messages_publishing: messages_publishing,
        messages_publishing_link: messages_publishing_link,
        messages_dequeued: messages_dequeued,
        messages_dequeued_link: messages_dequeued_link,
        messages_queued: messages_queued,
        messages_queued_link: messages_queued_link
      }
    end

    post '/update_per_page' do
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

      redirect outboxer_path(normalised_params)
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

      paginated_messages = Messages.list(
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
        per_page: params[:per_page]&.to_i || Messages::LIST_PER_PAGE_DEFAULT
      }
    end

    HEADERS = {
      'id' => 'Id',
      'status' => 'Status',
      'messageable' => 'Messageable',
      'updated_at' => 'Updated At',
      'created_at' => 'Created At'
    }

    def generate_pagination(current_page:, total_pages:, params:)
      previous_page = nil
      pages = []
      next_page = nil

      if current_page > 1
        previous_page = {
          text: 'Previous',
          href: outboxer_path("/messages" + normalise_params(
            status: params[:status], sort: params[:sort], order: params[:order],
            page: current_page - 1, per_page: params[:per_page]))
        }
      end

      pages = (([current_page - 4, 1].max)..([current_page + 4, total_pages].min)).map do |page|
        {
          text: page,
          href: outboxer_path("/messages" + normalise_params(
            status: params[:status], sort: params[:sort], order: params[:order], page: page,
            per_page: params[:per_page])),
          is_active: current_page == page
        }
      end

      if current_page < total_pages
        next_page = {
          text: 'Next',
          href: outboxer_path("/messages" + normalise_params(
            status: params[:status], sort: params[:sort], order: params[:order],
            page: current_page + 1, per_page: params[:per_page]))
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
              href: outboxer_path('/messages' + normalise_params(
                status: params[:status],
                order: 'desc',
                sort: header_key,
                page: 1,
                per_page: params[:per_page]
              ))
            }
          else
            {
              text: header_text,
              icon_class: 'bi bi-arrow-down',
              href: outboxer_path('/messages' + normalise_params(
                status: params[:status],
                order: 'asc',
                sort: header_key,
                page: 1,
                per_page: params[:per_page]
              ))
            }
          end
        else
          {
            text: header_text,
            icon_class: '',
            href: outboxer_path('/messages' + normalise_params(
              status: params[:status],
              order: 'asc',
              sort: header_key,
              page: 1,
              per_page: params[:per_page]))
          }
        end
      end
    end

    def denormalise_params(status: Messages::LIST_STATUS_DEFAULT,
                           sort: Messages::LIST_SORT_DEFAULT,
                           order: Messages::LIST_ORDER_DEFAULT,
                           page: Messages::LIST_PAGE_DEFAULT,
                           per_page: Messages::LIST_PER_PAGE_DEFAULT)
      {
        status: params[:status] || Messages::LIST_STATUS_DEFAULT,
        sort: params[:sort] || Messages::LIST_SORT_DEFAULT,
        order: params[:order] || Messages::LIST_ORDER_DEFAULT,
        page: params[:page]&.to_i || Messages::LIST_PAGE_DEFAULT,
        per_page: params[:per_page]&.to_i || Messages::LIST_PER_PAGE_DEFAULT
      }
    end

    def normalise_params(status: Messages::LIST_STATUS_DEFAULT,
                         sort: Messages::LIST_SORT_DEFAULT,
                         order: Messages::LIST_ORDER_DEFAULT,
                         page: Messages::LIST_PAGE_DEFAULT,
                         per_page: Messages::LIST_PER_PAGE_DEFAULT)
      normalised_params = {
        status: status == Messages::LIST_STATUS_DEFAULT ? nil : status,
        sort: sort == Messages::LIST_SORT_DEFAULT ? nil : sort,
        order: order == Messages::LIST_ORDER_DEFAULT ? nil : order,
        page: page == Messages::LIST_PAGE_DEFAULT ? nil : page,
        per_page: per_page == Messages::LIST_PER_PAGE_DEFAULT ? nil : per_page
      }.compact

      normalised_params.empty? ? '' : "?#{URI.encode_www_form(normalised_params)}"
    end

    post '/messages/update' do
      ids = params[:selected_ids].map(&:to_i)

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

      redirect to("/messages#{normalised_params}")
    end

    post '/messages/requeue_all' do
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

      result = Messages.requeue_all(status: denormalised_params[:status])

      message_text = result[:requeue_count] == 1 ? 'message' : 'messages'
      flash[:primary] = "#{result[:requeue_count]} #{message_text} have been queued"

      redirect to("/messages#{normalised_params}")
    end

    post '/messages/delete_all' do
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

      result = Messages.delete_all(status: denormalised_params[:status])

      message_text = result[:deleted_count] == 1 ? 'message' : 'messages'
      flash[:primary] = "#{result[:deleted_count]} #{message_text} have been deleted"

      redirect to("/messages#{normalised_params}")
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

      redirect to("/messages#{normalised_params}")
    end

    get '/message/:id' do
      message_status_counts = Messages.counts_by_status

      message = Message.find_by_id(id: params[:id])

      denormalised_params = denormalise_params(
        status: params[:status],
        sort: params[:sort],
        order: params[:order],
        page: params[:page]&.to_i,
        per_page: params[:per_page]&.to_i)

      erb :message, locals: {
        message_status_counts: message_status_counts,
        denormalised_params: denormalised_params,
        message: message
      }
    end

    post '/message/:id/requeue' do
      Message.requeue(id: params[:id])

      flash[:primary] = "Message #{params[:id]} was queued"

      redirect to('/messages')
    end

    post '/message/:id/delete' do
      Message.delete(id: params[:id])

      flash[:primary] = "Message #{params[:id]} was deleted"

      redirect to('/messages')
    end
  end
end
