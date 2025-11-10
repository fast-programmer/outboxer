module Outboxer
  module Models
    class Message
      class Count < ActiveRecord::Base
        self.table_name = "outboxer_message_counts"

        HISTORIC_HOSTNAME   = "historic"
        HISTORIC_PROCESS_ID = 0
        HISTORIC_THREAD_ID  = 0

        def self.insert_or_increment_by(
          hostname: Socket.gethostname,
          process_id: Process.pid,
          thread_id: Thread.current.object_id,
          queued: 0,
          publishing: 0,
          published: 0,
          failed: 0,
          current_utc_time: Time.now.utc
        )
          deltas = {
            queued: queued,
            publishing: publishing,
            published: published,
            failed: failed
          }.reject { |_k, v| v == 0 }

          cols = %i[
            hostname process_id thread_id
            queued publishing published failed
            created_at updated_at
          ]

          placeholders = (["?"] * cols.size).join(", ")

          conflict_clause = if connection.adapter_name.downcase.include?("postgres")
                              "ON CONFLICT (hostname, process_id, thread_id)"
                            else
                              "ON DUPLICATE KEY"
                            end

          updates = deltas.map do |k, v|
            op = v.positive? ? "+" : "-"
            if connection.adapter_name.downcase.include?("postgres")
              # e.g. "queued = outboxer_message_counts.queued + 2"
              "#{k} = #{table_name}.#{k} #{op} #{v.abs}"
            else
              # e.g. "queued = queued + 2"
              "#{k} = #{k} #{op} #{v.abs}"
            end
          end

          updates << (
            if connection.adapter_name.downcase.include?("postgres")
              "updated_at = EXCLUDED.updated_at"
            else
              "updated_at = VALUES(updated_at)"
            end
          )

          sql = <<~SQL
            INSERT INTO #{table_name}
              (#{cols.join(", ")})
            VALUES (#{placeholders})
            #{conflict_clause}
            DO UPDATE SET #{updates.join(", ")}
          SQL
          # Example (PostgreSQL):
          # INSERT INTO outboxer_message_counts
          #   (hostname, process_id, thread_id, queued, publishing, published, failed,
          #    created_at, updated_at)
          # VALUES ('test', 111, 123, 1, 0, 0, 0, '2025-11-10 06:32:00',
          #         '2025-11-10 06:32:00')
          # ON CONFLICT (hostname, process_id, thread_id)
          # DO UPDATE SET queued = outboxer_message_counts.queued + 1,
          #               updated_at = EXCLUDED.updated_at
          #
          # Example (MySQL):
          # INSERT INTO outboxer_message_counts
          #   (hostname, process_id, thread_id, queued, publishing, published, failed,
          #    created_at, updated_at)
          # VALUES ('test', 111, 123, 1, 0, 0, 0, '2025-11-10 06:32:00',
          #         '2025-11-10 06:32:00')
          # ON DUPLICATE KEY UPDATE queued = queued + 1,
          #                         updated_at = VALUES(updated_at)

          values = [
            hostname,
            process_id,
            thread_id,
            queued,
            publishing,
            published,
            failed,
            current_utc_time,
            current_utc_time
          ]

          connection.exec_query(sanitize_sql_array([sql, *values]))
          nil
        end
      end
    end
  end
end
