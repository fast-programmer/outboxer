require "logger"
require "active_record"

module Outboxer
  module Messages
    extend self

    class Error < Outboxer::Error; end;
    class InvalidParameter < Error; end

    def unpublished!(limit: 1, order: :asc)
      ActiveRecord::Base.connection_pool.with_connection do
        message_ids = ActiveRecord::Base.transaction do
          ids = Models::Message
            .where(status: Models::Message::Status::UNPUBLISHED)
            .order(created_at: order)
            .lock('FOR UPDATE SKIP LOCKED')
            .limit(limit)
            .pluck(:id)

          if !ids.empty?
            Models::Message.where(id: ids).update_all(status: Models::Message::Status::PUBLISHING)
          end

          ids
        end

        Models::Message
          .where(id: message_ids, status: Models::Message::Status::PUBLISHING)
          .order(created_at: order)
          .to_a
      end
    end

    def list(status: nil, sort: :updated_at, order: :asc, page: 1, per_page: 100)
      if !status.nil? && !Models::Message::STATUSES.include?(status)
        raise InvalidParameter, "status must be #{Models::Message::STATUSES.join(' ')}"
      end

      sort_options = [:id, :status, :messageable, :created_at, :updated_at]
      if !sort_options.include?(sort)
        raise InvalidParameter, "sort must be #{sort_options.join(' ')}"
      end

      order_options = [:asc, :desc]
      if !order_options.include?(order)
        raise InvalidParameter, "order must be #{order_options.join(' ')}"
      end

      if !page.is_a?(Integer) || page <= 0
        raise InvalidParameter, "page must be >= 1"
      end

      per_page_options = [100, 200, 500, 1000]
      if !per_page_options.include?(per_page)
        raise InvalidParameter, "per_page must be #{per_page_options.join(' ')}"
      end

      messages = status.nil? ? Models::Message.all : Models::Message.where(status: status)

      messages =
        if sort == :messageable
          messages.order(messageable_type: order, messageable_id: order)
        else
          messages.order(sort => order)
        end

      ActiveRecord::Base.connection_pool.with_connection do
        messages.page(page).per(per_page)
      end
    end
  end
end
