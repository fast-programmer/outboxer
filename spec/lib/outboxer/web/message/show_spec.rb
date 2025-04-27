require "rails_helper"

require_relative "../../../../../app/models/application_record"
require_relative "../../../../../app/models/event"

require_relative "../../../../../lib/outboxer/web"

RSpec.describe "GET /message/:id", type: :request do
  include Rack::Test::Methods

  def app
    Outboxer::Web
  end

  let(:messageable) { double("Event", id: "1", class: double(name: "Event")) }
  let!(:message) { Outboxer::Message.queue(messageable: messageable) }

  before do
    header "Host", "localhost"

    get "/message/#{message[:id]}"
  end

  it "loads message" do
    expect(last_response).to be_ok
    expect(last_response.body).to include(message[:id].to_s)
  end
end
