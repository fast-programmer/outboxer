sidekiq_ui: bundle exec rackup config.ru -p 3000
outboxer_message_backlogger: bundle exec ruby script/message/backlogger.rb
outboxer_message_publisher: bin/outboxer_message_publisher
outboxer_ui: PORT=4567 bundle exec rerun "ruby web/app.rb"
