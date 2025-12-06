module Outboxer
  module Models
    class Message
      class Counter < ActiveRecord::Base
        self.table_name = "outboxer_message_counters"

        HISTORIC_HOSTNAME   = "historic"
        HISTORIC_PROCESS_ID = 0
        HISTORIC_THREAD_ID  = 0

        def self.increment_counts_by(
          hostname: Socket.gethostname,
          process_id: Process.pid,
          thread_id: Thread.current.object_id,
          queued_delta: 0,
          publishing_delta: 0,
          published_delta: 0,
          failed_delta: 0,
          current_utc_time: Time.now.utc
        )
          update_values = {}
          table = arel_table

          if queued_delta.is_a?(Integer) && queued_delta != 0
            update_values[:queued_count] =
              table[:queued_count] + queued_delta
            update_values[:queued_count_last_updated_at] =
              current_utc_time
          end

          if publishing_delta.is_a?(Integer) && publishing_delta != 0
            update_values[:publishing_count] =
              table[:publishing_count] + publishing_delta
            update_values[:publishing_count_last_updated_at] =
              current_utc_time
          end

          if published_delta.is_a?(Integer) && published_delta != 0
            update_values[:published_count] =
              table[:published_count] + published_delta
            update_values[:published_count_last_updated_at] =
              current_utc_time
          end

          if failed_delta.is_a?(Integer) && failed_delta != 0
            update_values[:failed_count] =
              table[:failed_count] + failed_delta
            update_values[:failed_count_last_updated_at] =
              current_utc_time
          end

          if update_values.any?
            update_values[:updated_at] = current_utc_time

            where(
              hostname: hostname,
              process_id: process_id,
              thread_id: thread_id
            ).update_all(update_values)
          end
        end
      end
    end
  end
end
