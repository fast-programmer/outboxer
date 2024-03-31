# require_relative '../app/models/message'
# require_relative '../app/models/outboxer_exception'

now = Time.now
today = Time.new(now.year, now.month, now.day, 0, 0, 0, now.utc_offset)

5.times do |i|
  created_at = today - (i + 1).days + rand(0..23).hours + rand(0..59).minutes + rand(0..59).seconds

  Outboxer::Models::Message.create!(
    messageable_type: 'Event',
    messageable_id: i + 1,
    status: Outboxer::Models::Message::Status::PUBLISHING,
    created_at: created_at,
    updated_at: created_at + rand(0..23).hours + rand(0..59).minutes + rand(0..59).seconds)
end

15.times do |i|
  created_at = today - (i + 21).days + rand(0..23).hours + rand(0..59).minutes + rand(0..59).seconds

  Outboxer::Models::Message.create!(
    messageable_type: 'Event',
    messageable_id: i + 6,
    status: Outboxer::Models::Message::Status::UNPUBLISHED,
    created_at: created_at,
    updated_at: created_at + rand(0..23).hours + rand(0..59).minutes + rand(0..59).seconds)
end

5.times do |i|
  created_at = today - (i + 30).days + rand(0..23).hours + rand(0..59).minutes + rand(0..59).seconds

  failed_message = Outboxer::Models::Message.create!(
    messageable_type: 'Event',
    messageable_id: i + 21,
    status: Outboxer::Models::Message::Status::FAILED,
    created_at: created_at,
    updated_at: created_at + rand(0..23).hours + rand(0..59).minutes + rand(0..59).seconds)

  failed_message_exception = failed_message.exceptions.create!(
    class_name: 'ActiveRecord::RecordInvalid',
    message_text: 'Validation failed: Exceptions is invalid')

  failed_message_exception.frames.create!(
    index: 0,
    text: "/lib/active_record/validations.rb:84:in `raise_validation_error'")

  failed_message_exception.frames.create!(
    index: 1,
    text: "/lib/active_record/validations.rb:55:in `save!'")

  failed_message_exception.frames.create!(
    index: 2,
    text: "lib/active_record/transactions.rb:313:in `block in save!'")
end
