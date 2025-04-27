require "rails_helper"

require_relative "../../../../../lib/outboxer/web"

RSpec.describe "POST /publisher/:id/delete", type: :request do
  include Rack::Test::Methods

  def app
    Outboxer::Web
  end

  let(:messageable) { double("Event", id: 123, class: double(name: "Event")) }
  let!(:message) { Outboxer::Message.queue(messageable: messageable) }

  let(:publisher) { create(:outboxer_publisher, :publishing, name: "Test Publisher") }

  before do
    header "Host", "localhost"
    post "/publisher/#{publisher.id}/delete"

    follow_redirect!
  end

  it "deletes publisher" do
    expect(Outboxer::Models::Publisher.exists?(publisher.id)).to be false
  end

  it "displays flash" do
    expect(last_response).to be_ok
    expected_flash = URI.encode_www_form_component("success:Deleted publisher #{publisher.id}")
    expect(last_request.url).to include("flash=#{expected_flash}")
  end
end
