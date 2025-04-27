require "rails_helper"

require_relative "../../../../../app/models/application_record"

require_relative "../../../../../lib/outboxer/web"

RSpec.describe "POST /message/:id/delete", type: :request do
  include Rack::Test::Methods

  def app
    Outboxer::Web
  end

  let(:messageable) { double("Event", id: 123, class: double(name: "Event")) }
  let!(:message) { Outboxer::Message.queue(messageable: messageable) }

  before do
    header "Host", "localhost"

    post "/message/#{message[:id]}/delete"

    follow_redirect!
  end

  it "deletes message" do
    expect(Outboxer::Models::Message.exists?(message[:id])).to be false
  end

  it "redirects with flash" do
    expect(last_response).to be_ok
    expected_flash = URI.encode_www_form_component("success:Deleted message 1")
    expect(last_request.url).to include("flash=#{expected_flash}")
  end
end
