module EventService
  module_function

  def find_by_id(id:)
    ActiveRecord::Base.connection_pool.with_connection do
      Event.find(id)
    end
  end
end
