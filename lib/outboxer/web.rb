require "bundler/setup"

logger = Logger.new($stdout)

begin
  require "sinatra"
rescue LoadError
  error_message = <<~ERROR
    [Outboxer::Web] Sinatra is required to run the web interface. Add this to your Gemfile:
      gem 'sinatra'
    Then run `bundle install` to install the required gem.
  ERROR
  logger.error(error_message.strip)
  raise LoadError, error_message.strip
end

require "outboxer"
require "sinatra/base"
require "uri"

environment = ENV["RAILS_ENV"] || "development"

config = Outboxer::Database.config(environment: environment, concurrency: 5)
Outboxer::Database.connect(config: config)

module Outboxer
  # The Web interface for Outboxer, providing a web-based view into the system's operations,
  # including message management and publisher monitoring. This class extends Sinatra::Base,
  # configuring routes and helpers to serve HTTP requests for the Outboxer system.
  #
  # @note This class requires Sinatra to be available and is meant to be mounted or run
  #       as a standalone web application.
  class Web < Sinatra::Base
    set :logger, Logger.new($stdout)
    set :views, File.expand_path("web/views", __dir__)
    set :public_folder, File.expand_path("web/public", __dir__)
    set :show_exceptions, false

    configure do
      Setting.create_all
    end

    helpers do
      def outboxer_path(path)
        "#{request.script_name}#{path}"
      end

      def stringify_flash(flash)
        flash.map { |type, message| "#{type}:#{message}" }.join("&")
      end

      def pluralise(count, singular, plural = nil)
        if count == 1
          "#{count} #{singular}"
        else
          (plural.nil? ? "#{count} #{singular}s" : "#{count} #{plural}")
        end
      end

      def pretty_number(number:, delimiter: ",", separator: ".")
        return "-" if number.nil?

        integer, decimal = number.to_s.split(".")
        formatted_integer = integer.chars.reverse.each_slice(3).map(&:join).join(delimiter).reverse
        [formatted_integer, decimal].compact.join(separator)
      end

      def pretty_throughput(per_second: 0)
        return "-" if per_second == 0

        "#{pretty_number(number: per_second)} /s"
      end

      def pretty_duration_from_period(start_time:,
                                      end_time: ::Process.clock_gettime(::Process::CLOCK_MONOTONIC))
        pretty_duration(seconds: end_time - start_time)
      end

      def pretty_duration_from_seconds(seconds:)
        return "-" if seconds <= 0

        # Units for sub-second durations
        sub_second_units = [
          { name: "ns", scale: 1e-9 }, # 1 nanosecond = 10^-9 seconds
          { name: "μs", scale: 1e-6 }, # 1 microsecond = 10^-6 seconds
          { name: "ms", scale: 1e-3 }  # 1 millisecond = 10^-3 seconds
        ].freeze

        # Units for 1 second and above
        larger_units = [
          { name: "s", scale: 1 },       # 1 second
          { name: "min", scale: 60 },    # 1 minute = 60 seconds
          { name: "h", scale: 3_600 },   # 1 hour = 3,600 seconds
          { name: "d", scale: 86_400 },  # 1 day = 86,400 seconds
          { name: "w", scale: 604_800 }, # 1 week = 604,800 seconds
          { name: "mo", scale: 2_592_000 }, # 1 month = 2,592,000 seconds
          { name: "y", scale: 31_536_000 } # 1 year = 31,536,000 seconds
        ].freeze

        # Handle sub-second durations
        if seconds < 1
          sub_second_units.reverse_each do |unit|
            value = seconds / unit[:scale]
            return "#{pretty_number(number: value.to_i)}#{unit[:name]}" if value >= 1
          end
        end

        # Handle durations of 1 second and above
        result = []
        larger_units.reverse.each do |unit|
          next if seconds < unit[:scale] && result.empty?

          value, seconds = seconds.divmod(unit[:scale])
          result << "#{pretty_number(number: value.to_i)}#{unit[:name]}" if value > 0
        end

        result.join(" ")
      end

      def pretty_duration_from_seconds_to_milliseconds(seconds:)
        return "-" if seconds <= 0

        # Units for 1 second and above
        larger_units = [
          { name: "s", scale: 1 },       # 1 second
          { name: "min", scale: 60 },    # 1 minute = 60 seconds
          { name: "h", scale: 3_600 },   # 1 hour = 3,600 seconds
          { name: "d", scale: 86_400 },  # 1 day = 86,400 seconds
          { name: "w", scale: 604_800 }, # 1 week = 604,800 seconds
          { name: "mo", scale: 2_592_000 }, # 1 month = 2,592,000 seconds
          { name: "y", scale: 31_536_000 } # 1 year = 31,536,000 seconds
        ].freeze

        result = []

        # Handle larger units first
        larger_units.reverse.each do |unit|
          next if seconds < unit[:scale] && result.empty?

          value, seconds = seconds.divmod(unit[:scale])
          result << "#{value.to_i}#{unit[:name]}" if value > 0
        end

        # Handle milliseconds explicitly
        milliseconds = (seconds * 1_000).round
        result << "#{pretty_number(number: milliseconds)}ms" if milliseconds > 0 || result.empty?

        result.join(" ")
      end

      def human_readable_size(kilobytes:)
        units = ["KB", "MB", "GB", "TB"]
        size = kilobytes.to_f
        unit = units.shift

        while size > 1024 && units.any?
          size /= 1024
          unit = units.shift
        end

        "#{pretty_number(number: size.round(0))} #{unit}"
      end

      def time_ago_in_words(time)
        seconds = (::Time.now - time).to_i

        if seconds < 60
          "#{seconds} #{seconds == 1 ? "second" : "seconds"}"
        else
          prefix = seconds.negative? ? "from now" : "ago"
          seconds = seconds.abs

          case seconds
          when 0..59 then "#{seconds} seconds #{prefix}"
          when 60..3599 then "#{seconds / 60} minutes #{prefix}"
          when 3600..86_399 then "#{seconds / 3600} hours #{prefix}"
          when 86_400..2_591_999 then "#{seconds / 86_400} days #{prefix}"
          when 2_592_000..31_103_999 then "#{seconds / 2_592_000} months #{prefix}"
          else "#{seconds / 31_104_000} years #{prefix}"
          end
        end
      end
    end

    error StandardError do
      error = env["sinatra.error"]
      status 500

      puts "Error: #{error.class.name} - #{error.message}"

      erb :error, locals: { error: error }, layout: false
    end

    get "/" do
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

      messages_metrics = Message.metrics

      publishers = Publisher.all

      erb :home, locals: {
        messages_metrics: messages_metrics,
        denormalised_query_params: denormalised_query_params,
        normalised_query_params: normalised_query_params,
        normalised_query_string: normalised_query_string,
        publishers: publishers
      }
    end

    post "/update_time_zone" do
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

      redirect to(normalised_query_string)
    end

    get "/messages" do
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

      messages_metrics = Message.metrics

      paginated_messages = Message.list(
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
      id: "Id",
      status: "Status",
      messageable: "Messageable",
      queued_at: "Queued",
      updated_at: "Updated",
      publisher_name: "Publisher"
    }

    private

    def generate_pagination(current_page:, total_pages:, denormalised_query_params:)
      previous_page = nil
      next_page = nil

      if current_page > 1
        previous_page = {
          text: "Previous",
          href: outboxer_path(
            "/messages#{normalise_query_string(
              status: denormalised_query_params[:status],
              sort: denormalised_query_params[:sort],
              order: denormalised_query_params[:order],
              page: current_page - 1,
              per_page: denormalised_query_params[:per_page],
              time_zone: denormalised_query_params[:time_zone])}")
        }
      end

      pages = (([current_page - 4, 1].max)..([current_page + 4, total_pages].min)).map do |page|
        {
          text: page,
          href: outboxer_path("/messages#{normalise_query_string(
            status: denormalised_query_params[:status],
            sort: denormalised_query_params[:sort],
            order: denormalised_query_params[:order],
            page: page,
            per_page: denormalised_query_params[:per_page],
            time_zone: denormalised_query_params[:time_zone])}"),
          is_active: current_page == page
        }
      end

      if current_page < total_pages
        next_page = {
          text: "Next",
          href: outboxer_path("/messages#{normalise_query_string(
            status: denormalised_query_params[:status],
            sort: denormalised_query_params[:sort],
            order: denormalised_query_params[:order],
            page: current_page + 1,
            per_page: denormalised_query_params[:per_page],
            time_zone: denormalised_query_params[:time_zone])}")
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
              icon_class: "bi bi-arrow-up",
              href: outboxer_path("/messages#{normalise_query_string(
                status: denormalised_query_params[:status],
                order: :desc,
                sort: header_key,
                page: 1,
                per_page: denormalised_query_params[:per_page],
                time_zone: denormalised_query_params[:time_zone])}")
            }
          else
            {
              text: header_text,
              icon_class: "bi bi-arrow-down",
              href: outboxer_path("/messages#{normalise_query_string(
                status: denormalised_query_params[:status],
                order: :asc,
                sort: header_key,
                page: 1,
                per_page: denormalised_query_params[:per_page],
                time_zone: denormalised_query_params[:time_zone])}")
            }
          end
        else
          {
            text: header_text,
            icon_class: "",
            href: outboxer_path("/messages#{normalise_query_string(
              status: denormalised_query_params[:status],
              order: :asc,
              sort: header_key,
              page: 1,
              per_page: denormalised_query_params[:per_page],
              time_zone: denormalised_query_params[:time_zone])}")
          }
        end
      end
    end

    def denormalise_query_params(status: Message::LIST_STATUS_DEFAULT,
                                 sort: Message::LIST_SORT_DEFAULT,
                                 order: Message::LIST_ORDER_DEFAULT,
                                 page: Message::LIST_PAGE_DEFAULT,
                                 per_page: Message::LIST_PER_PAGE_DEFAULT,
                                 time_zone: Message::LIST_TIME_ZONE_DEFAULT)
      {
        status: status&.to_sym || Message::LIST_STATUS_DEFAULT,
        sort: sort&.to_sym || Message::LIST_SORT_DEFAULT,
        order: order&.to_sym || Message::LIST_ORDER_DEFAULT,
        page: page&.to_i || Message::LIST_PAGE_DEFAULT,
        per_page: per_page&.to_i || Message::LIST_PER_PAGE_DEFAULT,
        time_zone: time_zone&.to_s || Message::LIST_TIME_ZONE_DEFAULT
      }
    end

    def normalise_query_params(status: Message::LIST_STATUS_DEFAULT,
                               sort: Message::LIST_SORT_DEFAULT,
                               order: Message::LIST_ORDER_DEFAULT,
                               page: Message::LIST_PAGE_DEFAULT,
                               per_page: Message::LIST_PER_PAGE_DEFAULT,
                               time_zone: Message::LIST_TIME_ZONE_DEFAULT,
                               flash: {})
      {
        status: status == Message::LIST_STATUS_DEFAULT ? nil : status,
        sort: sort == Message::LIST_SORT_DEFAULT ? nil : sort,
        order: order == Message::LIST_ORDER_DEFAULT ? nil : order,
        page: page.to_i == Message::LIST_PAGE_DEFAULT ? nil : page,
        per_page: per_page.to_i == Message::LIST_PER_PAGE_DEFAULT ? nil : per_page,
        time_zone: time_zone.to_s == Message::LIST_TIME_ZONE_DEFAULT ? nil : time_zone,
        flash: flash.empty? ? nil : stringify_flash(flash)
      }.compact
    end

    def normalise_query_string(status: Message::LIST_STATUS_DEFAULT,
                               sort: Message::LIST_SORT_DEFAULT,
                               order: Message::LIST_ORDER_DEFAULT,
                               page: Message::LIST_PAGE_DEFAULT,
                               per_page: Message::LIST_PER_PAGE_DEFAULT,
                               time_zone: Message::LIST_TIME_ZONE_DEFAULT,
                               flash: {})
      normalised_query_params = normalise_query_params(
        status: status,
        sort: sort,
        order: order,
        page: page,
        per_page: per_page,
        time_zone: time_zone,
        flash: flash)

      normalised_query_params.empty? ? "" : "?#{URI.encode_www_form(normalised_query_params)}"
    end

    post "/messages/update" do
      ids = params[:selected_ids].map(&:to_i)
      flash = {}

      case params[:action]
      when "requeue_by_ids"
        result = Message.requeue_by_ids(ids: ids)

        if result[:requeued_count] > 0
          flash[:success] = "Requeued #{pluralise(result[:requeued_count], "message")}"
        end

        if !result[:not_requeued_ids].empty?
          flash[:danger] =
            "Requeue failed for #{pluralise(result[:not_requeued_ids].count, "message")}"
        end
      when "delete_by_ids"
        result = Message.delete_by_ids(ids: ids)

        if result[:deleted_count] > 0
          flash[:success] = "Deleted #{pluralise(result[:deleted_count], "message")}"
        end

        if !result[:not_deleted_ids].empty?
          flash[:danger] =
            "Delete failed for #{pluralise(result[:not_deleted_ids].count, "message")}"
        end
      else
        raise "Unknown action: #{params[:action]}"
      end

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
        time_zone: denormalised_query_params[:time_zone],
        flash: flash)

      redirect to("/messages#{normalised_query_string}")
    end

    post "/messages/requeue_all" do
      denormalised_query_params = denormalise_query_params(
        status: params[:status],
        sort: params[:sort],
        order: params[:order],
        page: params[:page],
        per_page: params[:per_page],
        time_zone: params[:time_zone])

      result = Message.requeue_all(
        status: denormalised_query_params[:status])

      normalised_query_string = normalise_query_string(
        status: denormalised_query_params[:status],
        sort: denormalised_query_params[:sort],
        order: denormalised_query_params[:order],
        page: denormalised_query_params[:page],
        per_page: denormalised_query_params[:per_page],
        time_zone: denormalised_query_params[:time_zone],
        flash: { success: "Requeued #{pluralise(result[:requeued_count], "message")}" })

      redirect to("/messages#{normalised_query_string}")
    end

    post "/messages/delete_all" do
      denormalised_query_params = denormalise_query_params(
        status: params[:status],
        sort: params[:sort],
        order: params[:order],
        page: params[:page],
        per_page: params[:per_page],
        time_zone: params[:time_zone])

      result = Message.delete_all(
        status: denormalised_query_params[:status], older_than: Time.now.utc)

      normalised_query_string = normalise_query_string(
        status: denormalised_query_params[:status],
        sort: denormalised_query_params[:sort],
        order: denormalised_query_params[:order],
        page: denormalised_query_params[:page],
        per_page: denormalised_query_params[:per_page],
        time_zone: denormalised_query_params[:time_zone],
        flash: { success: "Deleted #{pluralise(result[:deleted_count], "message")}" })

      redirect to("/messages#{normalised_query_string}")
    end

    post "/messages/update_per_page" do
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

    get "/message/:id" do
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

      messages_metrics = Message.metrics

      message = Message.find_by_id(id: params[:id])

      messageable_class = Object.const_get(message[:messageable_type])
      messageable = messageable_class.find_by_id(id: message[:messageable_id])

      erb :message, locals: {
        denormalised_query_params: denormalised_query_params,
        normalised_query_params: normalised_query_params,
        normalised_query_string: normalised_query_string,
        messages_metrics: messages_metrics,
        message: message,
        messageable: messageable
      }
    end

    get "/message/:id/messageable" do
      denormalised_query_params = denormalise_query_params(
        status: params[:status],
        sort: params[:sort],
        order: params[:order],
        page: params[:page],
        per_page: params[:per_page],
        time_zone: params[:time_zone])

      message = Message.find_by_id(id: params[:id])
      messages_metrics = Message.metrics

      messageable_class = Object.const_get(message[:messageable_type])
      messageable = messageable_class.find(message[:messageable_id])

      erb :messageable, locals: {
        message: message,
        messageable: messageable,
        messages_metrics: messages_metrics,
        denormalised_query_params: denormalised_query_params
      }
    end

    post "/message/:id/requeue" do
      Message.requeue(id: params[:id])

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
        time_zone: denormalised_query_params[:time_zone],
        flash: { success: "Requeued message #{params[:id]}" })

      redirect to("/messages#{normalised_query_string}")
    end

    post "/message/:id/delete" do
      Message.delete(id: params[:id])

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
        time_zone: denormalised_query_params[:time_zone],
        flash: { success: "Deleted message #{params[:id]}" })

      redirect to("/messages#{normalised_query_string}")
    end

    get "/publisher/:id" do
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

      publisher = Publisher.find_by_id(id: params[:id])

      messages_metrics = Message.metrics

      erb :publisher, locals: {
        messages_metrics: messages_metrics,
        denormalised_query_params: denormalised_query_params,
        normalised_query_params: normalised_query_params,
        normalised_query_string: normalised_query_string,
        publisher: publisher
      }
    end

    post "/publisher/:id/delete" do
      Publisher.delete(id: params[:id])

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
        time_zone: denormalised_query_params[:time_zone],
        flash: { success: "Deleted publisher #{params[:id]}" })

      redirect to(normalised_query_string.to_s)
    end

    post "/publisher/:id/signals" do
      Publisher.signal(id: params[:id], name: params[:name])

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
        time_zone: denormalised_query_params[:time_zone],
        flash: { success: "Signalled #{params[:name]} to publisher #{params[:id]}" })

      redirect to(normalised_query_string)
    end
  end
end
