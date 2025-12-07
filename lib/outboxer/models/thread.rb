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
        queued_message_count: 0,
        publishing_message_count: 0,
        published_message_count: 0,
        failed_message_count: 0,
        current_utc_time: Time.now.utc
      )
        is_postgres = connection.adapter_name.downcase.include?("postgres")

        insert_columns = %w[
          hostname process_id thread_id
          created_at updated_at
        ]

        insert_values = [
          hostname, process_id, thread_id,
          current_utc_time, current_utc_time
        ]

        update_columns = []
        update_values  = []

        if queued_message_count.to_i != 0
          insert_columns << "queued_message_count"
          insert_columns << "queued_message_count_last_updated_at"
          insert_values  << queued_message_count
          insert_values  << current_utc_time

          if is_postgres
            update_columns <<
              "queued_message_count = #{table_name}.queued_message_count + " \
              "EXCLUDED.queued_message_count"
          else
            update_columns << "queued_message_count = queued_message_count + ?"
            update_values  << queued_message_count
          end

          update_columns << "queued_message_count_last_updated_at = ?"
          update_values  << current_utc_time
        end

        if publishing_message_count.to_i != 0
          insert_columns << "publishing_message_count"
          insert_columns << "publishing_message_count_last_updated_at"
          insert_values  << publishing_message_count
          insert_values  << current_utc_time

          if is_postgres
            update_columns <<
              "publishing_message_count = #{table_name}.publishing_message_count + " \
              "EXCLUDED.publishing_message_count"
          else
            update_columns << "publishing_message_count = publishing_message_count + ?"
            update_values  << publishing_message_count
          end

          update_columns << "publishing_message_count_last_updated_at = ?"
          update_values  << current_utc_time
        end

        if published_message_count.to_i != 0
          insert_columns << "published_message_count"
          insert_columns << "published_message_count_last_updated_at"
          insert_values  << published_message_count
          insert_values  << current_utc_time

          if is_postgres
            update_columns <<
              "published_message_count = #{table_name}.published_message_count + " \
              "EXCLUDED.published_message_count"
          else
            update_columns << "published_message_count = published_message_count + ?"
            update_values  << published_message_count
          end

          update_columns << "published_message_count_last_updated_at = ?"
          update_values  << current_utc_time
        end

        if failed_message_count.to_i != 0
          insert_columns << "failed_message_count"
          insert_columns << "failed_message_count_last_updated_at"
          insert_values  << failed_message_count
          insert_values  << current_utc_time

          if is_postgres
            update_columns <<
              "failed_message_count = #{table_name}.failed_message_count + " \
              "EXCLUDED.failed_message_count"
          else
            update_columns << "failed_message_count = failed_message_count + ?"
            update_values  << failed_message_count
          end

          update_columns << "failed_message_count_last_updated_at = ?"
          update_values  << current_utc_time
        end

        update_columns << "updated_at = ?"
        update_values  << current_utc_time

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
