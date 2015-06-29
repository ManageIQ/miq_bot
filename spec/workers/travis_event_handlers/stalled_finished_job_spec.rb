require "spec_helper"

RSpec.describe TravisEventHandlers::StalledFinishedJob do
  %w(build:created build:started build:finished job:created job:started job:log).each do |type|
    it "skips events of type #{type}" do
      pr = 123
      slug = "foo/bar"
      number = 42
      state = "errored"
      event_hash = new_event_hash(pr, slug, number, state, type)
      repo = double("repo")
      job = double("job").as_null_object
      travis_repo = double("travis repo")
      allow(CommitMonitorRepo).to receive(:with_slug).with(slug).and_return(repo)
      allow(travis_repo).to receive(:job).with(number).and_return(job)

      expect(job).not_to receive(:restart)

      described_class.new.perform(event_hash)
    end
  end

  %w(created queued received started passed failed canceled ready).each do |state|
    it "skips jobs of state #{state}" do
      pr = 123
      slug = "foo/bar"
      number = 42
      type = "job:finished"
      event_hash = new_event_hash(pr, slug, number, state, type)
      repo = double("repo")
      job = double("job").as_null_object
      travis_repo = double("travis repo")
      allow(CommitMonitorRepo).to receive(:with_slug).with(slug).and_return(repo)
      allow(travis_repo).to receive(:job).with(number).and_return(job)

      expect(job).not_to receive(:restart)

      described_class.new.perform(event_hash)
    end
  end

  it "skips after 3 tries" do
    pr = 123
    slug = "foo/bar"
    number = 42
    state = "errored"
    type = "job:finished"
    event_hash = new_event_hash(pr, slug, number, state, type)
    repo = double("repo").as_null_object
    job = double("job").as_null_object
    travis_repo = double("travis repo")
    github = double("github")
    comment = double("comment", body: described_class::COMMENT_TAG)

    allow(github).to receive(:select_issue_comments).with(pr)
                      .and_return([comment, comment, comment])

    allow(repo).to receive(:with_github_service).and_yield(github)
    allow(CommitMonitorRepo).to receive(:with_slug).with(slug).and_return(repo)
    allow(travis_repo).to receive(:job).with(number).and_return(job)

    expect(job).not_to receive(:restart)

    described_class.new.perform(event_hash)
  end

  def new_event_hash(pr, slug, number, state, type)
    {
      "build" => {
        "pull_request_number" => pr,
      },
      "payload" => {
        "repository_slug" => slug,
        "number" => number,
        "state" => state,
      },
      "type" => type,
    }
  end
end
