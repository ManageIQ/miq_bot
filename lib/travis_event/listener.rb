module TravisEvent
  def self.handlers
    @handlers ||= begin
      workers_path = Rails.root.join("app/workers")
      Dir.glob(workers_path.join("travis_event_handlers/*.rb")).collect do |f|
        path = Pathname.new(f).relative_path_from(workers_path).to_s
        path.chomp(".rb").classify.constantize
      end
    end
  end

  class Listener
    ALL_EVENTS = %w(build:created build:started build:finished job:created job:started job:finished)

    # repos: ["rails/rails", "manageiq/manageiq"]
    def self.monitor(*slugs)
      Travis.listen(*travis_repos(slugs)) do |stream|
        stream.on(*ALL_EVENTS) do |event|
          hash = event_hash(event)
          if hash
            TravisEvent.handlers.each do |handler|
              handler.perform_async(hash)
            end
          end
        end
      end
    end

    def self.travis_repos(slugs)
      slugs = slugs.first if slugs.first.kind_of?(Array)
      slugs.collect { |slug| Travis::Repository.find(slug) }
    end

    def self.event_hash(event)
      unless %w(build job).include?(event.type.split(':').first)
        Sidekiq::Logging.logger.info("#{name}##{__method__} Discarding unsupported event type: #{event.type}")
        return nil
      end

      h = event.to_h
      h.keys.each do |k|
        v = h.delete(k)
        v = v.attributes if v.respond_to?(:attributes)
        h[k.to_s] = v
      end
      h
    end
  end
end

require 'travis'
TravisEvent::Listener.monitor(Settings.travis_event.enabled_repos)
