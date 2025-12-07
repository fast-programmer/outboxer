module Outboxer
  module Models
    class Thread < ActiveRecord::Base
      self.table_name = "outboxer_threads"

      HISTORIC_HOSTNAME   = "historic".freeze
      HISTORIC_PROCESS_ID = 0
      HISTORIC_THREAD_ID  = 0

      POSTGRES_SQL = <<~SQL.freeze
        INSERT INTO outboxer_threads (
          hostname,
          process_id,
          thread_id,
          queued_message_count,
          queued_message_count_last_updated_at,
          publishing_message_count,
          publishing_message_count_last_updated_at,
          published_message_count,
          published_message_count_last_updated_at,
          failed_message_count,
          failed_message_count_last_updated_at,
          created_at,
          updated_at
        )
        VALUES (
          $1, $2, $3,
          $4, $5,
          $6, $7,
          $8, $9,
          $10, $11,
          $12, $13
        )
        ON CONFLICT (hostname, process_id, thread_id)
        DO UPDATE SET
          queued_message_count =
            outboxer_threads.queued_message_count +
            EXCLUDED.queued_message_count,
          queued_message_count_last_updated_at =
            CASE
              WHEN EXCLUDED.queued_message_count != 0
              THEN EXCLUDED.queued_message_count_last_updated_at
              ELSE outboxer_threads.queued_message_count_last_updated_at
            END,
          publishing_message_count =
            outboxer_threads.publishing_message_count +
            EXCLUDED.publishing_message_count,
          publishing_message_count_last_updated_at =
            CASE
              WHEN EXCLUDED.publishing_message_count != 0
              THEN EXCLUDED.publishing_message_count_last_updated_at
              ELSE outboxer_threads.publishing_message_count_last_updated_at
            END,
          published_message_count =
            outboxer_threads.published_message_count +
            EXCLUDED.published_message_count,
          published_message_count_last_updated_at =
            CASE
              WHEN EXCLUDED.published_message_count != 0
              THEN EXCLUDED.published_message_count_last_updated_at
              ELSE outboxer_threads.published_message_count_last_updated_at
            END,
          failed_message_count =
            outboxer_threads.failed_message_count +
            EXCLUDED.failed_message_count,
          failed_message_count_last_updated_at =
            CASE
              WHEN EXCLUDED.failed_message_count != 0
              THEN EXCLUDED.failed_message_count_last_updated_at
              ELSE outboxer_threads.failed_message_count_last_updated_at
            END,
          updated_at = EXCLUDED.updated_at
      SQL

      MYSQL_SQL = <<~SQL.freeze
        INSERT INTO outboxer_threads (
          hostname,
          process_id,
          thread_id,
          queued_message_count,
          queued_message_count_last_updated_at,
          publishing_message_count,
          publishing_message_count_last_updated_at,
          published_message_count,
          published_message_count_last_updated_at,
          failed_message_count,
          failed_message_count_last_updated_at,
          created_at,
          updated_at
        )
        VALUES (
          ?, ?, ?,
          ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
        )
        ON DUPLICATE KEY UPDATE
          queued_message_count =
            queued_message_count + VALUES(queued_message_count),
          queued_message_count_last_updated_at =
            IF(
              VALUES(queued_message_count) != 0,
              VALUES(queued_message_count_last_updated_at),
              queued_message_count_last_updated_at
            ),
          publishing_message_count =
            publishing_message_count +
            VALUES(publishing_message_count),
          publishing_message_count_last_updated_at =
            IF(
              VALUES(publishing_message_count) != 0,
              VALUES(publishing_message_count_last_updated_at),
              publishing_message_count_last_updated_at
            ),
          published_message_count =
            published_message_count +
            VALUES(published_message_count),
          published_message_count_last_updated_at =
            IF(
              VALUES(published_message_count) != 0,
              VALUES(published_message_count_last_updated_at),
              published_message_count_last_updated_at
            ),
          failed_message_count =
            failed_message_count + VALUES(failed_message_count),
          failed_message_count_last_updated_at =
            IF(
              VALUES(failed_message_count) != 0,
              VALUES(failed_message_count_last_updated_at),
              failed_message_count_last_updated_at
            ),
          updated_at = VALUES(updated_at)
      SQL

      def self.update_message_counts_by!(
        hostname: Socket.gethostname,
        process_id: Process.pid,
        thread_id: ::Thread.current.object_id,
        queued_message_count: 0,
        publishing_message_count: 0,
        published_message_count: 0,
        failed_message_count: 0,
        current_utc_time: Time.now.utc
      )
        adapter_name = connection.adapter_name.downcase
        is_postgres  = adapter_name.include?("postgres")

        values = [
          hostname,
          process_id,
          thread_id,

          queued_message_count,
          queued_message_count.to_i != 0 ? current_utc_time : nil,

          publishing_message_count,
          publishing_message_count.to_i != 0 ? current_utc_time : nil,

          published_message_count,
          published_message_count.to_i != 0 ? current_utc_time : nil,

          failed_message_count,
          failed_message_count.to_i != 0 ? current_utc_time : nil,

          current_utc_time,
          current_utc_time
        ]

        sql = is_postgres ? POSTGRES_SQL : MYSQL_SQL

        connection.exec_query(sql, "Outboxer::Thread", values)
      end
    end
  end
end
