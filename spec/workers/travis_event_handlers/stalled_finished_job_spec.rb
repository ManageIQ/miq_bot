require "spec_helper"

RSpec.describe TravisEventHandlers::StalledFinishedJob do
  %w(build:created build:started build:finished job:created job:started job:log).each do |type|
    it "skips events of type #{type}" do
      slug = "foo/bar"
      number = 42
      state = "errored"
      event_hash = new_event_hash(slug, number, state, type)
      repo = double("repo")
      allow(CommitMonitorRepo).to receive(:with_slug).with(slug).and_return(repo)
      job = double("job").as_null_object
      travis_repo = double("travis repo")
      allow(travis_repo).to receive(:job).with(number).and_return(job)

      expect(job).not_to receive(:restart)

      described_class.new.perform(event_hash)
    end
  end
  %w(created queued received started passed failed canceled ready).each do |state|
    it "skips jobs that of state #{state}" do
      slug = "foo/bar"
      number = 42
      type = "job:finished"
      event_hash = new_event_hash(slug, number, state, type)
      repo = double("repo")
      allow(CommitMonitorRepo).to receive(:with_slug).with(slug).and_return(repo)
      job = double("job").as_null_object
      travis_repo = double("travis repo")
      allow(travis_repo).to receive(:job).with(number).and_return(job)

      expect(job).not_to receive(:restart)

      described_class.new.perform(event_hash)
    end
  end

  def new_event_hash(slug, number, state, type)
    {
      "payload" => {
        "repository_slug" => slug,
        "number" => number,
        "state" => state,
      },
      "type" => type,
    }
  end
end
