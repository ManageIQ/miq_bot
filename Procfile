thin:                      bundle exec rails s -p $PORT
sidekiq:                   bundle exec sidekiq -q miq_bot
issue_manager:             bundle exec ruby lib/bot/miq_bot.rb
travis_listener:           bundle exec rails runner lib/travis_event/listener.rb
#rails:                     tail -f -n 0 log/development.log
