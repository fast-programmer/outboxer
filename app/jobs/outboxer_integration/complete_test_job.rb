module OutboxerIntegration
  class CompleteTestJob
    include Sidekiq::Job

    def perform(args)
      TestService.complete(
        user_id: args["user_id"],
        tenant_id: args["tenant_id"],
        id: args["id"],
        lock_version: args["lock_version"])
    end
  end
end
