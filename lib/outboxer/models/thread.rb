module Outboxer
  module Models
    class Thread < ActiveRecord::Base
      self.table_name = "outboxer_threads"

      HISTORIC_HOSTNAME   = "historic"
      HISTORIC_PROCESS_ID = 0
      HISTORIC_THREAD_ID  = 0

      def self.update_message_counts_by!(
        hostname: Socket.gethostname,
        process_id: Process.pid,
        thread_id: ::Thread.current.object_id,
        queued_count: 0,
        publishing_count: 0,
        published_count: 0,
        failed_count: 0,
        current_utc_time: Time.now.utc
      )
        is_postgres = connection.adapter_name.downcase.include?("postgres")

        # -----------------------------
        # INSERT (base)
        # -----------------------------
        insert_columns = %w[
          hostname
          process_id
          thread_id
          created_at
          updated_at
        ]

        insert_values = [
          hostname,
          process_id,
          thread_id,
          current_utc_time,
          current_utc_time
        ]

        # -----------------------------
        # UPDATE (base)
        # -----------------------------
        update_columns = []
        update_values  = []

        # -----------------------------
        # QUEUED
        # -----------------------------
        if queued_count.to_i != 0
          insert_columns << "queued_count" << "queued_count_last_updated_at"
          insert_values << queued_count << current_utc_time

          if is_postgres
            update_columns << "queued_count = #{table_name}.queued_count + EXCLUDED.queued_count"
          else
            update_columns << "queued_count = queued_count + ?"
            update_values  << queued_count
          end

          update_columns << "queued_count_last_updated_at = ?"
          update_values  << current_utc_time
        end

        # -----------------------------
        # PUBLISHING
        # -----------------------------
        if publishing_count.to_i != 0
          insert_columns << "publishing_count" << "publishing_count_last_updated_at"
          insert_values << publishing_count << current_utc_time

          if is_postgres
            update_columns <<
              "publishing_count = #{table_name}.publishing_count + EXCLUDED.publishing_count"
          else
            update_columns << "publishing_count = publishing_count + ?"
            update_values  << publishing_count
          end

          update_columns << "publishing_count_last_updated_at = ?"
          update_values  << current_utc_time
        end

        # -----------------------------
        # PUBLISHED
        # -----------------------------
        if published_count.to_i != 0
          insert_columns << "published_count" << "published_count_last_updated_at"
          insert_values  << published_count   << current_utc_time

          if is_postgres
            update_columns <<
              "published_count = #{table_name}.published_count + EXCLUDED.published_count"
          else
            update_columns << "published_count = published_count + ?"
            update_values  << published_count
          end

          update_columns << "published_count_last_updated_at = ?"
          update_values  << current_utc_time
        end

        # -----------------------------
        # FAILED
        # -----------------------------
        if failed_count.to_i != 0
          insert_columns << "failed_count" << "failed_count_last_updated_at"
          insert_values << failed_count << current_utc_time

          if is_postgres
            update_columns << "failed_count = #{table_name}.failed_count + EXCLUDED.failed_count"
          else
            update_columns << "failed_count = failed_count + ?"
            update_values << failed_count
          end

          update_columns << "failed_count_last_updated_at = ?"
          update_values << current_utc_time
        end

        # -----------------------------
        # ALWAYS bump updated_at
        # -----------------------------
        update_columns << "updated_at = ?"
        update_values << current_utc_time

        # -----------------------------
        # SQL BUILD
        # -----------------------------
        insert_sql = <<~SQL
          INSERT INTO #{table_name} (#{insert_columns.join(", ")})
          VALUES (#{(["?"] * insert_columns.length).join(", ")})
        SQL

        sql =
          if is_postgres
            <<~SQL
              #{insert_sql}
              ON CONFLICT (hostname, process_id, thread_id)
              DO UPDATE SET
                #{update_columns.join(",\n                ")}
            SQL
          else
            <<~SQL
              #{insert_sql}
              ON DUPLICATE KEY UPDATE
                #{update_columns.join(",\n                ")}
            SQL
          end

        connection.exec_query(
          sanitize_sql_array([sql, *insert_values, *update_values])
        )
      end
    end
  end
end
