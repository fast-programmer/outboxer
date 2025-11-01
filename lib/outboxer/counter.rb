module Outboxer
  module Counter
    HISTORIC_HOSTNAME   = "historic"
    HISTORIC_PROCESS_ID = 0
    HISTORIC_THREAD_ID  = 0

    # Rolls up thread_counters for the given publisher_id into the historic_counter,
    # then destroys rolled-up thread_counters.
    #
    # @param time [Time] timestamp context for updated_at
    # @return [Hash] new historic_totals after rollup
    def self.rollup(time: Time)
      current_utc_time = time.now.utc

      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          # 1. Ensure the historic counter exists (idempotent upsert)
          Models::Counter.insert_or_increment_by(
            hostname: HISTORIC_HOSTNAME,
            process_id: HISTORIC_PROCESS_ID,
            thread_id: HISTORIC_THREAD_ID,
            current_utc_time: current_utc_time
          )

          # 2. Lock *all* rows (historic counter + thread counters)
          locked_counters = Models::Counter.lock("FOR UPDATE").to_a

          # 3. Identify the historic counter
          historic_counter = locked_counters.find do |r|
            r.hostname == HISTORIC_HOSTNAME &&
              r.process_id == HISTORIC_PROCESS_ID &&
              r.thread_id == HISTORIC_THREAD_ID
          end

          # 4. Everything else is a thread counter
          thread_counters = locked_counters - [historic_counter]

          # 5. Sum all thread counters
          totals = thread_counters.each_with_object(
            queued_count: 0, publishing_count: 0, published_count: 0, failed_count: 0
          ) do |row, sum|
            sum[:queued_count] += row.queued_count
            sum[:publishing_count] += row.publishing_count
            sum[:published_count] += row.published_count
            sum[:failed_count] += row.failed_count
          end

          # 6. Update historic counter
          historic_counter.update!(
            queued_count: historic_counter.queued_count + totals[:queued_count],
            publishing_count: historic_counter.publishing_count + totals[:publishing_count],
            published_count: historic_counter.published_count + totals[:published_count],
            failed_count: historic_counter.failed_count + totals[:failed_count],
            updated_at: current_utc_time
          )

          # 7. Delete all rolled-up rows except historic
          Models::Counter.where.not(
            hostname: HISTORIC_HOSTNAME,
            process_id: HISTORIC_PROCESS_ID,
            thread_id: HISTORIC_THREAD_ID
          ).delete_all

          # 8. Return the updated totals
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
