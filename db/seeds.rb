begin
  Outboxer::Models::Setting.create!(
    name: 'messages.published.count.historic', value: '0')

  Outboxer::Models::Setting.create!(
    name: 'messages.failed.count.historic', value: '0')
rescue ActiveRecord::RecordNotUnique
  # no op as record already exists
end
