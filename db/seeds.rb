# require_relative '../app/models/message'
# require_relative '../app/models/outboxer_exception'

100.times do |i|
  messageable_type = 'Event'
  messageable_id = 1

  Outboxer::Models::Message
    .create!(
      outboxer_messageable_type: messageable_type,
      outboxer_messageable_id: messageable_id,
      status: Outboxer::Models::Message::STATUS[:unpublished])

  Outboxer::Models::Message
    .create!(
      outboxer_messageable_type: messageable_type,
      outboxer_messageable_id: messageable_id,
      status: Outboxer::Models::Message::STATUS[:publishing])

  failed_message = Outboxer::Models::Message
    .create!(
      outboxer_messageable_type: messageable_type,
      outboxer_messageable_id: messageable_id,
      status: Outboxer::Models::Message::STATUS[:failed])

  failed_message
    .outboxer_exceptions
    .create!(
      class_name: 'StandardError',
      message_text: 'Sample error message',
      backtrace: ['Sample backtrace line 1', 'Sample backtrace line 2'])

  failed_message
    .outboxer_exceptions
    .create!(
      class_name: 'StandardError',
      message_text: 'Sample error message',
      backtrace: ['Sample backtrace line 1', 'Sample backtrace line 2'])
end
