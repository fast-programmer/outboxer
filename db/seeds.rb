begin
  Outboxer::Models::Metric.create!(
    name: 'messages.published.count.historic', value: BigDecimal('0'))
rescue ActiveRecord::RecordNotUnique
  # no op as record already exists
end
