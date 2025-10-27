module Outboxer
  module Counter
    HISTORIC_HOSTNAME   = "historic"
    HISTORIC_PROCESS_ID = 0
    HISTORIC_THREAD_ID  = 0

    # Rolls up thread_counters for the given publisher_id into the historic_counter,
    # then destroys rolled-up thread_counters.
    #
    # @param publisher_id [Integer] publisher to roll up
    # @param time [Time] timestamp context for updated_at
    # @return [Hash] new historic_totals after rollup
    def self.rollup(publisher_id:, time:)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          Models::Counter.insert_or_increment_by(
            hostname: HISTORIC_HOSTNAME,
            process_id: HISTORIC_PROCESS_ID,
            thread_id: HISTORIC_THREAD_ID,
            time: time
          )

          historic_counter = Models::Counter.lock("FOR UPDATE").find_by!(
            hostname: HISTORIC_HOSTNAME,
            process_id: HISTORIC_PROCESS_ID,
            thread_id: HISTORIC_THREAD_ID
          )

          thread_counters = Models::Counter.lock("FOR UPDATE")
            .where("publisher_id = ? OR publisher_id IS NULL", publisher_id)
            .where.not(
              hostname: HISTORIC_HOSTNAME,
              process_id: HISTORIC_PROCESS_ID,
              thread_id: HISTORIC_THREAD_ID)

          thread_counter_totals = Models::Counter
            .where(id: thread_counters.select(:id))
            .select(
              "COALESCE(SUM(queued_count), 0) AS queued_count",
              "COALESCE(SUM(publishing_count), 0) AS publishing_count",
              "COALESCE(SUM(published_count), 0) AS published_count",
              "COALESCE(SUM(failed_count), 0) AS failed_count"
            ).take.attributes.symbolize_keys.slice(
              :queued_count, :publishing_count, :published_count, :failed_count)

          historic_counter.update!(
            queued_count: historic_counter.queued_count + thread_counter_totals[:queued_count],
            publishing_count: historic_counter.publishing_count +
              thread_counter_totals[:publishing_count],
            published_count: historic_counter.published_count +
              thread_counter_totals[:published_count],
            failed_count: historic_counter.failed_count + thread_counter_totals[:failed_count],
            updated_at: time
          )

          thread_counters.destroy_all

          {
            queued_count: historic_counter.queued_count,
            publishing_count: historic_counter.publishing_count,
            published_count: historic_counter.published_count,
            failed_count: historic_counter.failed_count
          }
        end
      end
    end

    # Returns total counts across the historic_counter and all thread_counters.
    #
    # @return [Hash] total counts across all rows
    def self.total
      ActiveRecord::Base.connection_pool.with_connection do
        result = Models::Counter.select(
          "COALESCE(SUM(queued_count), 0) AS queued_count",
          "COALESCE(SUM(publishing_count), 0) AS publishing_count",
          "COALESCE(SUM(published_count), 0) AS published_count",
          "COALESCE(SUM(failed_count), 0) AS failed_count"
        ).take

        result.attributes.symbolize_keys.slice(
          :queued_count, :publishing_count, :published_count, :failed_count
        )
      end
    end
  end
end
