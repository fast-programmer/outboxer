# outboxer_message_backlogger: bundle exec ruby script/message/backlogger.rb
sidekiq: bundle exec sidekiq -C config/sidekiq.yml -r ./config/sidekiq.rb
outboxer_message_publisher: bin/outboxer_message_publisher
outboxer_app: bundle exec rerun "rackup -p 3000"
