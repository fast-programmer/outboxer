module OutboxerIntegration
  module TestService
    module_function

    def start(user_id:, tenant_id:, time: Time)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          current_time = time.current
          test = Test.create!(
            tenant_id: tenant_id, created_at: current_time, updated_at: current_time)

          event = TestStartedEvent.create!(
            user_id: user_id,
            tenant_id: tenant_id,
            created_at: time.current,
            eventable: test,
            index: test.lock_version,
            body: {
              "test" => {
                "id" => test.id,
                "lock_version" => test.lock_version
              }
            })

          [test, event]
        end
      end
    end

    def complete(user_id:, tenant_id:, id:, lock_version:, time: Time)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          test = Test.find_by!(tenant_id: tenant_id, id: id)
          test.update!(lock_version: lock_version, updated_at: time.current)

          event = TestCompletedEvent.create!(
            user_id: user_id,
            tenant_id: tenant_id,
            created_at: time.current,
            eventable: test,
            index: test.lock_version,
            body: {
              "test" => {
                "id" => test.id,
                "lock_version" => test.lock_version
              }
            })

          [test, event]
        end
      end
    end
  end
end
