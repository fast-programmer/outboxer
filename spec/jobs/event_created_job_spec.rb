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
        hash_including("class" => "ContactCreatedJob", "args" => [1])
      ])
    end

    it "enqueues Accountify::ContactCreatedJob" do
      stub_const("Accountify", Module.new)
      stub_const("Accountify::ContactCreatedJob", Class.new { include Sidekiq::Job })

      EventCreatedJob.new.perform({ "id" => 2, "type" => "Accountify::ContactCreatedEvent" })

      expect(Accountify::ContactCreatedJob.jobs).to match([
        hash_including("class" => "Accountify::ContactCreatedJob", "args" => [2])
      ])
    end

    it "enqueues Accountify::InvoiceUpdatedJob" do
      stub_const("Accountify", Module.new) unless defined?(Accountify)
      stub_const("Accountify::InvoiceUpdatedJob", Class.new { include Sidekiq::Job })

      EventCreatedJob.new.perform({ "id" => 3, "type" => "Accountify::InvoiceUpdatedEvent" })

      expect(Accountify::InvoiceUpdatedJob.jobs).to match([
        hash_including("class" => "Accountify::InvoiceUpdatedJob", "args" => [3])
      ])
    end

    it "enqueues Accountify::Invoice::CreatedJob" do
      stub_const("Accountify", Module.new)
      stub_const("Accountify::Invoice", Module.new)
      stub_const("Accountify::Invoice::CreatedJob", Class.new { include Sidekiq::Job })

      EventCreatedJob.new.perform({ "id" => 4, "type" => "Accountify::Invoice::CreatedEvent" })

      expect(Accountify::Invoice::CreatedJob.jobs).to match([
        hash_including("class" => "Accountify::Invoice::CreatedJob", "args" => [4])
      ])
    end

    it "enqueues MyApp::Domain::Event::UserSignedUpJob" do
      stub_const("MyApp", Module.new)
      stub_const("MyApp::Domain", Module.new)
      stub_const("MyApp::Domain::Event", Module.new)
      stub_const("MyApp::Domain::Event::UserSignedUpJob", Class.new { include Sidekiq::Job })

      EventCreatedJob.new.perform(
        { "id" => 5, "type" => "MyApp::Domain::Event::UserSignedUpEvent" })

      expect(MyApp::Domain::Event::UserSignedUpJob.jobs).to match([
        hash_including("class" => "MyApp::Domain::Event::UserSignedUpJob", "args" => [5])
      ])
    end

    it "handles leading :: in type" do
      stub_const("ContactCreatedJob", Class.new { include Sidekiq::Job })

      EventCreatedJob.new.perform({ "id" => 6, "type" => "::ContactCreatedEvent" })

      expect(ContactCreatedJob.jobs).to match([
        hash_including("class" => "ContactCreatedJob", "args" => [6])
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
        "Could not get job class name from event type: bad_type")

      EventCreatedJob.new.perform({ "id" => 13, "type" => "bad_type" })
    end

    it "logs debug message when job class name is not constantizable" do
      expect(Sidekiq.logger).to receive(:debug).with(
        "Could not constantize job class name: ImaginaryThingJob")

      EventCreatedJob.new.perform({ "id" => 14, "type" => "ImaginaryThingEvent" })
    end
  end

  describe ".perform_async" do
    before { Sidekiq::Worker.clear_all }

    it "enqueues ContactCreatedJob through perform_async" do
      stub_const("ContactCreatedJob", Class.new { include Sidekiq::Job })

      EventCreatedJob.perform_async({ "id" => 1, "type" => "ContactCreatedEvent" })
      EventCreatedJob.drain

      expect(ContactCreatedJob.jobs).to match([
        hash_including("class" => "ContactCreatedJob", "args" => [1])
      ])
    end

    it "enqueues Accountify::ContactCreatedJob through perform_async" do
      stub_const("Accountify", Module.new)
      stub_const("Accountify::ContactCreatedJob", Class.new { include Sidekiq::Job })

      EventCreatedJob.perform_async({ "id" => 2, "type" => "Accountify::ContactCreatedEvent" })
      EventCreatedJob.drain

      expect(Accountify::ContactCreatedJob.jobs).to match([
        hash_including("class" => "Accountify::ContactCreatedJob", "args" => [2])
      ])
    end

    it "enqueues Accountify::InvoiceUpdatedJob through perform_async" do
      stub_const("Accountify", Module.new) unless defined?(Accountify)
      stub_const("Accountify::InvoiceUpdatedJob", Class.new { include Sidekiq::Job })

      EventCreatedJob.perform_async({ "id" => 3, "type" => "Accountify::InvoiceUpdatedEvent" })
      EventCreatedJob.drain

      expect(Accountify::InvoiceUpdatedJob.jobs).to match([
        hash_including("class" => "Accountify::InvoiceUpdatedJob", "args" => [3])
      ])
    end

    it "enqueues Accountify::Invoice::CreatedJob through perform_async" do
      stub_const("Accountify", Module.new)
      stub_const("Accountify::Invoice", Module.new)
      stub_const("Accountify::Invoice::CreatedJob", Class.new { include Sidekiq::Job })

      EventCreatedJob.perform_async({ "id" => 4, "type" => "Accountify::Invoice::CreatedEvent" })
      EventCreatedJob.drain

      expect(Accountify::Invoice::CreatedJob.jobs).to match([
        hash_including("class" => "Accountify::Invoice::CreatedJob", "args" => [4])
      ])
    end

    it "enqueues MyApp::Domain::Event::UserSignedUpJob through perform_async" do
      stub_const("MyApp", Module.new)
      stub_const("MyApp::Domain", Module.new)
      stub_const("MyApp::Domain::Event", Module.new)
      stub_const("MyApp::Domain::Event::UserSignedUpJob", Class.new { include Sidekiq::Job })

      EventCreatedJob.perform_async({
        "id" => 5,
        "type" => "MyApp::Domain::Event::UserSignedUpEvent"
      })
      EventCreatedJob.drain

      expect(MyApp::Domain::Event::UserSignedUpJob.jobs).to match([
        hash_including("class" => "MyApp::Domain::Event::UserSignedUpJob", "args" => [5])
      ])
    end

    it "handles leading :: in type through perform_async" do
      stub_const("ContactCreatedJob", Class.new { include Sidekiq::Job })

      EventCreatedJob.perform_async({ "id" => 6, "type" => "::ContactCreatedEvent" })
      EventCreatedJob.drain

      expect(ContactCreatedJob.jobs).to match([
        hash_including("class" => "ContactCreatedJob", "args" => [6])
      ])
    end

    it "does not enqueue job for invalid type format" do
      expect do
        EventCreatedJob.perform_async({ "id" => 7, "type" => "contact_created_event" })
      end.not_to change(EventCreatedJob.jobs, :size)
    end

    it "does not enqueue job for empty string" do
      expect do
        EventCreatedJob.perform_async({ "id" => 8, "type" => "" })
      end.not_to change(EventCreatedJob.jobs, :size)
    end

    it "does not enqueue job if type does not end in Event" do
      expect do
        EventCreatedJob.perform_async({ "id" => 9, "type" => "SomethingCreated" })
      end.not_to change(EventCreatedJob.jobs, :size)
    end

    it "skips perform_async for missing job class" do
      EventCreatedJob.perform_async({ "id" => 10, "type" => "ImaginaryThingEvent" })
      EventCreatedJob.drain

      expect(Sidekiq::Worker.jobs.size).to eq(0)
    end

    it "skips perform_async for invalid constant path" do
      EventCreatedJob.perform_async({ "id" => 11, "type" => "123::@@@Invalid" })
      EventCreatedJob.drain

      expect(Sidekiq::Worker.jobs.size).to eq(0)
    end

    it "skips perform_async if type is exactly 'Event'" do
      EventCreatedJob.perform_async({ "id" => 12, "type" => "Event" })
      EventCreatedJob.drain

      expect(Sidekiq::Worker.jobs.size).to eq(0)
    end

    it "returns nil for invalid type" do
      result = EventCreatedJob.perform_async({ "id" => 13, "type" => "bad_type" })
      expect(result).to be_nil
    end

    it "returns job ID when enqueued" do
      stub_const("ContactCreatedJob", Class.new { include Sidekiq::Job })

      result = EventCreatedJob.perform_async({ "id" => 14, "type" => "ContactCreatedEvent" })
      expect(result).to be_a(String)
    end
  end
end
