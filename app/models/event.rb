class Event
  attr_accessor :id

  def self.find(id)
    new(
      id: id,
      name: 'Stubbed Event',
      description: 'This is a stubbed event for testing purposes.',
      created_at: Time.now.utc,
      header: {
        'user' => { 'id' => 1, 'name' => 'Alice', 'email' => 'alice@example.com' },
        'location' => { 'city' => 'New York', 'coordinates' => { 'lat' => 40.7128, 'lon' => -74.0060 } }
      },
      body: {
        'title' => 'Event Title',
        'description' => 'This is a description of the event.',
        'attendees' => [{ 'id' => 1, 'name' => 'Bob' }, { 'id' => 2, 'name' => 'Charlie' }]
      }
    )
  end

  def initialize(id:, name:, description:, created_at:, header:, body:)
    @id = id
    @name = name
    @description = description
    @created_at = created_at
    @header = header
    @body = body
  end

  def attributes
    {
      'id' => @id,
      'name' => @name,
      'description' => @description,
      'created_at' => @created_at,
      'header' => @header,
      'body' => @body
    }
  end
end
