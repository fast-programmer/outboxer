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

        insert_columns = %w[hostname process_id thread_id created_at updated_at]
        insert_values = [hostname, process_id, thread_id, current_utc_time, current_utc_time]

        update_columns = []
        update_values  = []

        [
          [:queued, queued_message_count],
          [:publishing, publishing_message_count],
          [:published, published_message_count],
          [:failed, failed_message_count]
        ]
          .reject { |_name, message_count| message_count.to_i == 0 }
          .each do |name, message_count|
            message_count_column = "#{name}_message_count"
            message_count_last_updated_at_column = "#{name}_message_count_last_updated_at"

            insert_columns << message_count_column
            insert_columns << message_count_last_updated_at_column
            insert_values  << message_count
            insert_values  << current_utc_time

            if is_postgres
              update_columns <<
                "#{message_count_column} = #{table_name}.#{message_count_column} + " \
                "EXCLUDED.#{message_count_column}"
            else
              update_columns << "#{message_count_column} = #{message_count_column} + ?"
              update_values << message_count
            end

            update_columns << "#{message_count_last_updated_at_column} = ?"
            update_values << current_utc_time
          end

        update_columns << "updated_at = ?"
        update_values << current_utc_time

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
