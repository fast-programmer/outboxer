# require_relative '../app/models/message'
# require_relative '../app/models/outboxer_exception'

100.times do |i|
  messageable_type = 'Event'
  messageable_id = 1

  Outboxer::Models::Message
    .create!(
      messageable_type: messageable_type,
      messageable_id: messageable_id,
      status: Outboxer::Models::Message::Status::UNPUBLISHED)

  Outboxer::Models::Message
    .create!(
      messageable_type: messageable_type,
      messageable_id: messageable_id,
      status: Outboxer::Models::Message::Status::PUBLISHING)

  Outboxer::Models::Message
    .create!(
      messageable_type: messageable_type,
      messageable_id: messageable_id,
      status: Outboxer::Models::Message::Status::FAILED,
      exceptions: [
        Outboxer::Models::Exception.build(
          class_name: 'StandardError',
          message_text: 'Sample error message',
          frames: [
            Outboxer::Models::Frame.build(
              file_name: 'test.rb',
              line_number: 5,
              method_name: 'some_bug' )])])

  # Outboxer::Models::Message
  #   .create!(
  #     messageable_type: messageable_type,
  #     messageable_id: messageable_id,
  #     status: Outboxer::Models::Message::Status::FAILED,
  #     exceptions: [
  #       Outboxer::Models::Exception.build(
  #         class_name: 'StandardError',
  #         message_text: 'Sample error message',
  #         frames: [
  #           Outboxer::Models::Frame.build(
  #             file_name: 'test.rb',
  #             line_number: 5,
  #             method_name: 'some_bug' )])])

  # failed_message
  #   .exceptions
  #   .create!(
  #     class_name: 'StandardError',
  #     message_text: 'Sample error message',
  #     backtrace: ['Sample backtrace line 1', 'Sample backtrace line 2'])
end
