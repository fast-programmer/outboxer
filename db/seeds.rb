# require_relative '../app/models/message'
# require_relative '../app/models/outboxer_exception'

5.times do |i|
  Outboxer::Models::Message.create!(
    messageable_type: 'Event',
    messageable_id: i,
    status: Outboxer::Models::Message::Status::PUBLISHING)
end

15.times do |i|
  Outboxer::Models::Message.create!(
    messageable_type: 'Event',
    messageable_id: i + 5,
    status: Outboxer::Models::Message::Status::UNPUBLISHED)
end

5.times do |i|
  failed_message = Outboxer::Models::Message.create!(
    messageable_type: 'Event',
    messageable_id: i + 20,
    status: Outboxer::Models::Message::Status::FAILED)

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
