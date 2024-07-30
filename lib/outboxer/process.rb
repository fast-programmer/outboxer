module Outboxer
  module Process
    extend self

    def log_metrics(statsd:, interval:, logger:, current_time_utc: Time.now.utc)
      pid = ::Process.pid

      begin
        memory_usage = `ps -o rss= -p #{pid}`.to_i
        virtual_memory_usage = `ps -o vsz= -p #{pid}`.to_i
        cpu_usage = `ps -o %cpu= -p #{pid}`.to_f
        thread_count = Thread.list.size
        open_file_descriptors = `lsof -p #{pid} | wc -l`.to_i
        uptime = `ps -o etimes= -p #{pid}`.to_i

        disk_io_stats = { read_bytes: 0, write_bytes: 0 }
        network_io_stats = { read_bytes: 0, write_bytes: 0 }

        begin
          io_data = File.read("/proc/#{pid}/io")
          io_data.each_line do |line|
            if line.start_with?('read_bytes:')
              disk_io_stats[:read_bytes] = line.split(':').last.strip.to_i
            elsif line.start_with?('write_bytes:')
              disk_io_stats[:write_bytes] = line.split(':').last.strip.to_i
            end
          end

          net_data = File.read("/proc/net/dev")
          net_data.each_line do |line|
            if line.include?("eth0:")
              parts = line.split
              network_io_stats[:read_bytes] = parts[1].to_i
              network_io_stats[:write_bytes] = parts[9].to_i
            end
          end
        rescue Errno::ENOENT
          logger.error "Failed to read I/O or network stats: /proc/#{pid}/io or /proc/net/dev not found"
        end

        gc_stats = GC.stat

        statsd.batch do |batch|
          batch.gauge('outboxer.process.memory_usage', memory_usage)
          batch.gauge('outboxer.process.virtual_memory_usage', virtual_memory_usage)
          batch.gauge('outboxer.process.cpu_usage', cpu_usage)
          batch.gauge('outboxer.process.thread_count', thread_count)
          batch.gauge('outboxer.process.open_file_descriptors', open_file_descriptors)
          batch.gauge('outboxer.process.uptime', uptime)
          batch.gauge('outboxer.process.disk.io.read_bytes', disk_io_stats[:read_bytes])
          batch.gauge('outboxer.process.disk.io.write_bytes', disk_io_stats[:write_bytes])
          batch.gauge('outboxer.process.network.io.read_bytes', network_io_stats[:read_bytes])
          batch.gauge('outboxer.process.network.io.write_bytes', network_io_stats[:write_bytes])

          batch.gauge('outboxer.process.gc.count', gc_stats[:count])
          batch.gauge('outboxer.process.gc.minor_gc_count', gc_stats[:minor_gc_count])
          batch.gauge('outboxer.process.gc.major_gc_count', gc_stats[:major_gc_count])
          batch.gauge('outboxer.process.gc.total_allocated_objects', gc_stats[:total_allocated_objects])
          batch.gauge('outboxer.process.gc.total_freed_objects', gc_stats[:total_freed_objects])
          batch.gauge('outboxer.process.gc.heap_allocated_pages', gc_stats[:heap_allocated_pages])
          batch.gauge('outboxer.process.gc.heap_sorted_length', gc_stats[:heap_sorted_length])
          batch.gauge('outboxer.process.gc.heap_allocatable_pages', gc_stats[:heap_allocatable_pages])
          batch.gauge('outboxer.process.gc.total_allocated_pages', gc_stats[:total_allocated_pages])
          batch.gauge('outboxer.process.gc.total_freed_pages', gc_stats[:total_freed_pages])
        end

        logger.info "Process metrics logged: Memory usage: #{memory_usage} KB, Virtual memory usage: #{virtual_memory_usage} KB, CPU usage: #{cpu_usage}%, Thread count: #{thread_count}, Open file descriptors: #{open_file_descriptors}, Uptime: #{uptime} s, Disk I/O read: #{disk_io_stats[:read_bytes]} bytes, Disk I/O write: #{disk_io_stats[:write_bytes]} bytes, Network I/O read: #{network_io_stats[:read_bytes]} bytes, Network I/O write: #{network_io_stats[:write_bytes]} bytes"
      rescue => e
        logger.error "Failed to send process metrics: #{e.message}"
      end
    end
  end
end
