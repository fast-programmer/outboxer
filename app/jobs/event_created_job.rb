class EventCreatedJob
  include Sidekiq::Job

  def perform(args)
    job_class_name = to_job_class_name(type: args["type"])

    if job_class_name.nil?
      Sidekiq.logger.debug("Could not get job class name from event type: #{args["type"]}")

      return
    end

    job_class = job_class_name.safe_constantize

    if job_class.nil?
      Sidekiq.logger.debug("Could not constantize job class name: #{job_class_name}")

      return
    end

    job_class.perform_async(args["id"])
  end

  TYPE_REGEX = /\A(::)?([A-Z][\w]*::)*[A-Z][\w]*Event\z/

  def to_job_class_name(type:)
    self.class.can_handle?(type: type) ? type.sub(/Event\z/, "Job") : nil
  end

  def self.can_handle?(type:)
    # \A            => start of string
    # (::)?         => optional leading ::
    # ([A-Z]\w*::)* => zero or more namespace segments like Foo:: or FooBar::
    # [A-Z]\w*      => final constant segment (starts with capital letter)
    # Event\z       => ends with 'Event', anchors to end of string
    #
    # Valid examples:
    #   ✔ ContactCreatedEvent
    #   ✔ ::ContactCreatedEvent
    #   ✔ Accountify::ContactCreatedEvent
    #   ✔ Accountify::Invoice::CreatedEvent
    #   ✔ MyApp::Domain::Event::UserSignedUpEvent
    #
    # Invalid examples:
    #   ✘ contactCreatedEvent          # starts lowercase
    #   ✘ ContactCreated               # missing 'Event'
    #   ✘ Event                        # just 'Event'
    #   ✘ 123::InvalidEvent            # starts with digit
    #   ✘ Foo::                        # incomplete constant

    /\A(::)?([A-Z][\w]*::)*[A-Z][\w]*Event\z/.match?(type)
  end
end
