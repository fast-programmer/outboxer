require "rails_helper"

RSpec.describe EventService do
  describe ".find_by_id" do
    let!(:event) do
      Event.create!(user_id: 1, tenant_id: 1, type: "Event", created_at: Time.current)
    end

    it "returns the event with the given id" do
      expect(EventService.find_by_id(id: event.id)).to eq(event)
    end

    it "raises ActiveRecord::RecordNotFound if event does not exist" do
      expect do
        EventService.find_by_id(id: -1)
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
