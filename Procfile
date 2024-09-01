# outboxer_message_queuer: bundle exec ruby script/message/queuer.rb
sidekiq: bundle exec sidekiq -C config/sidekiq.yml -r ./config/sidekiq.rb
outboxer_published_messages_deleter: bin/outboxer_published_messages_deleter
outboxer_publisher: bin/outboxer_publisher
outboxer_app: bundle exec rerun "rackup -p 4567"
