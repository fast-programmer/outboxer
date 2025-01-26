require "rails_helper"

require_relative "../../../../../app/models/application_record"
require_relative "../../../../../app/models/event"

require_relative "../../../../../lib/outboxer/web"

RSpec.describe "POST /messages/update_per_page", type: :request do
  include Rack::Test::Methods

  def app
    Outboxer::Web
  end

  before do
    header "Host", "localhost"

    post "/messages/update_per_page", {
      status: "queued",
      sort: "queued_at",
      order: "desc",
      page: 1,
      per_page: 10,
      time_zone: "Australia/Sydney"
    }

    follow_redirect!
  end

  it "redirects with updated per_page param" do
    expect(last_request.url).to include(
      "messages?status=queued&sort=queued_at&order=desc&per_page=10&time_zone=Australia%2FSydney")
  end
end
