require "rails_helper"

module Outboxer
  RSpec.describe PublisherService do
    describe ".config" do
      let(:path) { "spec/fixtures/config/outboxer.yml" }

      it "returns ERB interpolated environment override" do
        allow(ENV).to receive(:[]).with("RAILS_MAX_THREADS").and_return("4")
        config = PublisherService.config(environment: "test", path: path)
        expect(config).to eq({
          buffer: 100,
          concurrency: 4,
          tick: 0.1,
          poll: 5.0,
          heartbeat: 5.0,
          log_level: 1
        })
      end

      it "returns root values when environment not overridden" do
        expect(PublisherService.config(path: path)).to eq({
          buffer: 100,
          concurrency: 1,
          tick: 0.1,
          poll: 5.0,
          heartbeat: 5.0,
          log_level: 1
        })
      end

      it "returns environment overrides" do
        expect(PublisherService.config(environment: "development", path: path))
          .to eq({
            buffer: 100,
            concurrency: 2,
            tick: 0.1,
            poll: 5.0,
            heartbeat: 5.0,
            log_level: 1
          })
      end

      it "returns an empty hash when file is missing" do
        expect(PublisherService.config(path: "nonexistent/path.yml")).to eq({})
      end
    end
  end
end
