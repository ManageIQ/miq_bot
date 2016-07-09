namespace :travis_event_listener do
  desc "Run the Travis Event Listener"
  task :run => :environment do
    TravisEvent::Listener.run
  end
end
