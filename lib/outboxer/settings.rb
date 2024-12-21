module Outboxer
  module Settings
    extend self

    def upsert_defaults
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          Models::Setting.upsert({ name: 'messages.published.count.historic', value: '0' }, unique_by: :name)
          Models::Setting.upsert({ name: 'messages.failed.count.historic', value: '0' }, unique_by: :name)
        end
      end
    end
  end
end
