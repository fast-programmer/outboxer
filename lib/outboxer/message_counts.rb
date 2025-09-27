module Outboxer
  module MessageCounts
    module_function

    def by_status
      Message::STATUSES
        .index_with { 0 }
        .merge(Models::MessageCounts.group(:status).sum(:value).transform_keys(&:to_s))
    end
  end
end
