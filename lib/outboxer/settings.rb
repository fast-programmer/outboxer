module Outboxer
  module Settings
    module_function

    def create
      ActiveRecord::Base.connection_pool.with_connection do
        begin
          Outboxer::Models::Setting.create!(name: "messages.published.count.historic", value: "0")
        rescue ActiveRecord::RecordNotUnique
          # no op as record already exists
        end

        begin
          Outboxer::Models::Setting.create!(name: "messages.failed.count.historic", value: "0")
        rescue ActiveRecord::RecordNotUnique
          # no op as record already exists
        end
      end
    end
  end
end
