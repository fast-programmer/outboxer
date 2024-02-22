# require_relative '../app/models/message'
# require_relative '../app/models/outboxer_exception'

100.times do |i|
  outboxable_type = 'Event'
  outboxable_id = 1

  Outboxer::Models::Message.create!(
    outboxable_type: outboxable_type,
    outboxable_id: outboxable_id,
    status: Outboxer::Models::Message::Status::UNPUBLISHED)

  Outboxer::Models::Message.create!(
    outboxable_type: outboxable_type,
    outboxable_id: outboxable_id,
    status: Outboxer::Models::Message::Status::PUBLISHING)

  failed_message = Outboxer::Models::Message.create!(
    outboxable_type: outboxable_type,
    outboxable_id: outboxable_id,
    status: Outboxer::Models::Message::Status::FAILED)

  failed_message_exception = failed_message.exceptions.create!(
    class_name: 'ActiveRecord::RecordInvalid',
    message_text: 'Validation failed: Exceptions is invalid')

  failed_message_exception.frames.create!(
    index: 0, text: "/lib/active_record/validations.rb:84:in `raise_validation_error'")

  failed_message_exception.frames.create!(
    index: 1, text: "/lib/active_record/validations.rb:55:in `save!'")

  failed_message_exception.frames.create!(
    index: 2, text: "lib/active_record/transactions.rb:313:in `block in save!'")
end
