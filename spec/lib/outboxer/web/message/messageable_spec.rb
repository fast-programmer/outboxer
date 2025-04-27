require "rails_helper"

require_relative "../../../../../lib/outboxer/web"

RSpec.describe "GET /message/:id/messageable", type: :request do
  include Rack::Test::Methods

  def app
    Outboxer::Web
  end

  let(:messageable) { double("Event", id: 123, class: double(name: "Event")) }
  let!(:message) { Outboxer::Message.queue(messageable: messageable) }

  before do
    header "Host", "localhost"

    get "/message/#{message[:id]}/messageable"
  end

  it "loads the associated messageable object for a message" do
    expect(last_response).to be_ok
  end
end
