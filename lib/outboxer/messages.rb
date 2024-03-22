require "logger"
require "active_record"

module Outboxer
  module Messages
    extend self

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
      if !status.nil? && !Models::Message::STATUSES.include?(status.to_s)
        raise ArgumentError, "status must be #{Models::Message::STATUSES.join(' ')}"
      end

      sort_options = [:id, :status, :messageable, :created_at, :updated_at]
      if !sort_options.include?(sort.to_sym)
        raise ArgumentError, "sort must be #{sort_options.join(' ')}"
      end

      order_options = [:asc, :desc]
      if !order_options.include?(order.to_sym)
        raise ArgumentError, "order must be #{order_options.join(' ')}"
      end

      if !page.is_a?(Integer) || page <= 0
        raise ArgumentError, "page must be >= 1"
      end

      per_page_options = [100, 200, 500, 1000]
      if !per_page_options.include?(per_page)
        raise ArgumentError, "per_page must be #{per_page_options.join(' ')}"
      end

      message_scope = Models::Message
      message_scope = status.nil? ? message_scope.all : message_scope.where(status: status)

      message_scope =
        if sort.to_sym == :messageable
          message_scope.order(messageable_type: order.to_sym, messageable_id: order.to_sym)
        else
          message_scope.order(sort.to_sym => order.to_sym)
        end

      messages = ActiveRecord::Base.connection_pool.with_connection do
        message_scope.page(page).per(per_page)
      end

      messages.map do |message|
        {
          'id' => message.id,
          'status' => message.status,
          'messageable' => "#{message.messageable_type}::#{message.messageable_id}",
          'created_at' => message.created_at.utc.to_s,
          'updated_at' => message.updated_at.utc.to_s
        }
      end
    end
  end
end
