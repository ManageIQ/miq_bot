thin:                      bundle exec rails s -p $PORT
sidekiq:                   bundle exec sidekiq -q cfme_bot
commit_monitor_poll:       bundle exec rake commit_monitor:poll
pull_request_monitor_poll: bundle exec rake pull_request_monitor:poll
issue_manager:             cd lib/bot; bundle exec ruby cfme_bot.rb
#rails:                     tail -f -n 0 log/development.log
