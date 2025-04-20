require "rails_helper"
require "sidekiq/testing"

require_relative "../../app/jobs/event_created_job"

Sidekiq::Testing.fake!

RSpec.describe EventCreatedJob, type: :job do
  before { Sidekiq::Worker.clear_all }

  describe "#perform" do
    it "enqueues ContactCreatedJob" do
      stub_const("ContactCreatedJob", Class.new { include Sidekiq::Job })

      EventCreatedJob.new.perform({ "id" => 1, "type" => "ContactCreatedEvent" })

      expect(ContactCreatedJob.jobs).to match([
        hash_including("class" => "ContactCreatedJob", "args" => [{ "id" => 1 }])
      ])
    end

    it "enqueues Accountify::ContactCreatedJob" do
      stub_const("Accountify", Module.new)
      stub_const("Accountify::ContactCreatedJob", Class.new { include Sidekiq::Job })

      EventCreatedJob.new.perform({ "id" => 2, "type" => "Accountify::ContactCreatedEvent" })

      expect(Accountify::ContactCreatedJob.jobs).to match([
        hash_including("class" => "Accountify::ContactCreatedJob", "args" => [{ "id" => 2 }])
      ])
    end

    it "enqueues Accountify::InvoiceUpdatedJob" do
      stub_const("Accountify", Module.new) unless defined?(Accountify)
      stub_const("Accountify::InvoiceUpdatedJob", Class.new { include Sidekiq::Job })

      EventCreatedJob.new.perform({ "id" => 3, "type" => "Accountify::InvoiceUpdatedEvent" })

      expect(Accountify::InvoiceUpdatedJob.jobs).to match([
        hash_including("class" => "Accountify::InvoiceUpdatedJob", "args" => [{ "id" => 3 }])
      ])
    end

    it "enqueues Accountify::Invoice::CreatedJob" do
      stub_const("Accountify", Module.new)
      stub_const("Accountify::Invoice", Module.new)
      stub_const("Accountify::Invoice::CreatedJob", Class.new { include Sidekiq::Job })

      EventCreatedJob.new.perform({ "id" => 4, "type" => "Accountify::Invoice::CreatedEvent" })

      expect(Accountify::Invoice::CreatedJob.jobs).to match([
        hash_including("class" => "Accountify::Invoice::CreatedJob", "args" => [{ "id" => 4 }])
      ])
    end

    it "enqueues MyApp::Domain::Event::UserSignedUpJob" do
      stub_const("MyApp", Module.new)
      stub_const("MyApp::Domain", Module.new)
      stub_const("MyApp::Domain::Event", Module.new)
      stub_const("MyApp::Domain::Event::UserSignedUpJob", Class.new { include Sidekiq::Job })

      EventCreatedJob.new.perform({ "id" => 5, "type" => "MyApp::Domain::Event::UserSignedUpEvent" })

      expect(MyApp::Domain::Event::UserSignedUpJob.jobs).to match([
        hash_including("class" => "MyApp::Domain::Event::UserSignedUpJob", "args" => [{ "id" => 5 }])
      ])
    end

    it "handles leading :: in type" do
      stub_const("ContactCreatedJob", Class.new { include Sidekiq::Job })

      EventCreatedJob.new.perform({ "id" => 6, "type" => "::ContactCreatedEvent" })

      expect(ContactCreatedJob.jobs).to match([
        hash_including("class" => "ContactCreatedJob", "args" => [{ "id" => 6 }])
      ])
    end

    it "does not enqueue for invalid type format" do
      EventCreatedJob.new.perform({ "id" => 7, "type" => "contact_created_event" })
      expect(Sidekiq::Worker.jobs.size).to eq(0)
    end

    it "does not enqueue for empty string" do
      EventCreatedJob.new.perform({ "id" => 8, "type" => "" })
      expect(Sidekiq::Worker.jobs.size).to eq(0)
    end

    it "does not enqueue if type does not end in Event" do
      EventCreatedJob.new.perform({ "id" => 9, "type" => "SomethingCreated" })
      expect(Sidekiq::Worker.jobs.size).to eq(0)
    end

    it "does not enqueue for missing job class" do
      EventCreatedJob.new.perform({ "id" => 10, "type" => "ImaginaryThingEvent" })
      expect(Sidekiq::Worker.jobs.size).to eq(0)
    end

    it "does not enqueue for invalid type constant path" do
      EventCreatedJob.new.perform({ "id" => 11, "type" => "123::@@@Invalid" })
      expect(Sidekiq::Worker.jobs.size).to eq(0)
    end

    it "does not enqueue if type is exactly 'Event'" do
      EventCreatedJob.new.perform({ "id" => 12, "type" => "Event" })
      expect(Sidekiq::Worker.jobs.size).to eq(0)
    end

    it "logs debug message when type is invalid" do
      expect(Sidekiq.logger).to receive(:debug).with(
        "Could not get job class name from event type: bad_type"
      )

      EventCreatedJob.new.perform({ "id" => 13, "type" => "bad_type" })
    end

    it "logs debug message when job class name is not constantizable" do
      expect(Sidekiq.logger).to receive(:debug).with(
        "Could not constantize job class name: ImaginaryThingJob"
      )

      EventCreatedJob.new.perform({ "id" => 14, "type" => "ImaginaryThingEvent" })
    end
  end
end
