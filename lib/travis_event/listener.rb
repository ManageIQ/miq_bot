module TravisEvent
  class Listener
    ALL_EVENTS = %w(build:created build:started build:finished job:created job:started job:finished)

    def self.handlers
      @handlers ||=
        Dir.glob("lib/travis_event/handlers/*.rb").collect do |f|
          path = Pathname.new(f).relative_path_from(Pathname.new("lib")).to_s
          path.chomp(".rb").classify.constantize
        end
    end

    # repos: [Travis::Repository.find("rails/rails")]
    def self.monitor(*repos)
      Travis.listen(*repos) do |stream|
        stream.on(*ALL_EVENTS) do |event|
          args = extract_args(event)
          if args
            handlers.each do |handler|
              handler.perform_async(*args)
            end
          end
        end
      end
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
repos = Settings.travis_event.enabled_repos.collect do|repo|
  Travis::Repository.find(repo)
end

TravisEvent::Listener.monitor(*repos)
