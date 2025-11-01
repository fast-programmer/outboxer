module Outboxer
  module Models
    class Counter < ActiveRecord::Base
      self.table_name = "outboxer_counters"

      def self.insert_or_increment_by(
        hostname: Socket.gethostname,
        process_id: Process.pid,
        thread_id: Thread.current.object_id,
        queued_count: 0,
        publishing_count: 0,
        published_count: 0,
        failed_count: 0,
        time: Time.now.utc
      )
        now = time.utc

        sql = if connection.adapter_name.downcase.include?("postgres")
                <<~SQL
                  INSERT INTO #{table_name}
                    (hostname, process_id, thread_id,
                     queued_count, publishing_count, published_count, failed_count,
                     created_at, updated_at)
                  VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                  ON CONFLICT (hostname, process_id, thread_id)
                  DO UPDATE SET
                    queued_count     = #{table_name}.queued_count     + ?,
                    publishing_count = #{table_name}.publishing_count + ?,
                    published_count  = #{table_name}.published_count  + ?,
                    failed_count     = #{table_name}.failed_count     + ?,
                    updated_at       = ?
                SQL
              else
                <<~SQL
                  INSERT INTO #{table_name}
                    (hostname, process_id, thread_id,
                     queued_count, publishing_count, published_count, failed_count,
                     created_at, updated_at)
                  VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                  ON DUPLICATE KEY UPDATE
                    queued_count     = queued_count     + ?,
                    publishing_count = publishing_count + ?,
                    published_count  = published_count  + ?,
                    failed_count     = failed_count     + ?,
                    updated_at       = ?
                SQL
              end

        connection.exec_query(
          sanitize_sql_array([
            sql,
            hostname, process_id, thread_id,
            queued_count, publishing_count, published_count, failed_count,
            now, now,
            queued_count, publishing_count, published_count, failed_count, now
          ])
        )

        nil
      end
    end
  end
end
