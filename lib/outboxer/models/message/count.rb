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
          sql = if connection.adapter_name.downcase.include?("postgres")
                  <<~SQL
                    INSERT INTO #{table_name}
                      (hostname, process_id, thread_id,
                      queued, publishing, published, failed,
                      created_at, updated_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT (hostname, process_id, thread_id)
                    DO UPDATE SET
                      queued     = #{table_name}.queued     + ?,
                      publishing = #{table_name}.publishing + ?,
                      published  = #{table_name}.published  + ?,
                      failed     = #{table_name}.failed     + ?,
                      updated_at       = ?
                  SQL
                else
                  <<~SQL
                    INSERT INTO #{table_name}
                      (hostname, process_id, thread_id,
                      queued, publishing, published, failed,
                      created_at, updated_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ON DUPLICATE KEY UPDATE
                      queued     = queued     + ?,
                      publishing = publishing + ?,
                      published  = published  + ?,
                      failed     = failed     + ?,
                      updated_at       = ?
                  SQL
                end

          connection.exec_query(
            sanitize_sql_array([
              sql,
              hostname, process_id, thread_id,
              queued, publishing, published, failed,
              current_utc_time, current_utc_time,
              queued, publishing, published, failed, current_utc_time
            ])
          )

          nil
        end
      end
    end
  end
end
