require "rails_helper"

require_relative "../../../../../lib/outboxer/web"

RSpec.describe "POST /message/:id/requeue", type: :request do
  include Rack::Test::Methods

  def app
    Outboxer::Web
  end

  let(:messageable) { double("Event", id: 123, class: double(name: "Event")) }
  let!(:message) { Outboxer::Message.queue(messageable: messageable) }

  before do
    header "Host", "localhost"

    post "/message/#{message[:id]}/requeue"

    follow_redirect!
  end

  it "requeues a message" do
    expect(Outboxer::Models::Message.find(message[:id]).status).to eql("queued")
  end

  it "redirects with flash" do
    expect(last_response).to be_ok
    expected_flash = URI.encode_www_form_component("success:Requeued message 1")
    expect(last_request.url).to include("flash=#{expected_flash}")
  end
end
