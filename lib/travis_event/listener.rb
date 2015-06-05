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
          args = extract_args(event)
          if args
            TravisEvent.handlers.each do |handler|
              handler.perform_async(*args)
            end
          end
        end
      end
    end

    def self.travis_repos(slugs)
      slugs = slugs.first if slugs.first.kind_of?(Array)
      slugs.collect { |slug| Travis::Repository.find(slug) }
    end

    def self.extract_args(event)
      # Travis::Event is a:
      # Struct.new(:type, :repository, :build, :job, :payload)
      number, state, build =
        case event.type.split(':').first
        when 'build'
          [event.build.number, event.build.state, event.build]
        when 'job'
          [event.job.number, event.job.state, event.job.build]
        else
          Sidekiq::Logging.logger.info("#{name}##{__method__} Discarding unsupported event source type: #{event.type}")
          return nil
        end

      branch_or_pr_number = build.pull_request? ? build.pull_request_number : build.commit.branch
      [event.repository.slug, number, event.type, state, branch_or_pr_number]
    end
  end
end

require 'travis'
TravisEvent::Listener.monitor(Settings.travis_event.enabled_repos)
