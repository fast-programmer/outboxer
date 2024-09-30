class Event
  attr_accessor :id, :type

  def self.find(id)
    new(
      id: id,
      type: 'Accountify::Contact::CreatedEvent',
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

  def initialize(id:, type:, created_at:, header:, body:)
    @id = id
    @type = type
    @created_at = created_at
    @header = header
    @body = body
  end

  def attributes
    {
      'id' => @id,
      'type' => @type,
      'created_at' => @created_at,
      'header' => @header,
      'body' => @body
    }
  end
end
