module Outboxer
  module Setting
    module_function

    # Creates initial setting records in the database unless they already exist.
    # This method ensures that necessary settings for tracking message counts are initialized.
    #
    # It attempts to create settings for 'messages.published.count.historic' and
    # 'messages.failed.count.historic' with initial values set to "0". If these settings already
    # exist due to unique constraints in the database, the method will quietly handle the exception
    # without further action.
    def create_all
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
