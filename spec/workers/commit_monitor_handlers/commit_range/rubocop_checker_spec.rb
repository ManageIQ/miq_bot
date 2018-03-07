require 'spec_helper'

describe CommitMonitorHandlers::CommitRange::RubocopChecker do
  describe "#replace_rubocop_comments" do
    let(:num) { 42 }
    let(:repo) { "owner/repository" }
    let(:comments) { %w(comment1 comment2) }
    let(:sha) { "b0e6911a4b7cc8dcf6aa4ed28244a1d5fb90d051" }
    let(:commits) { ["x", "y", sha] }

    let(:results_no_status) { Hash("files"=> [Hash("offenses"=> [Hash("severity"=>"warn"), Hash("severity"=>"info")]), Hash("offenses"=> [Hash("severity"=>"unknown"), Hash("severity"=>"info")])]) }
    let(:results_red_status) { Hash("files"=> [Hash("offenses"=> [Hash("severity"=>"warn"), Hash("severity"=>"error")]), Hash("offenses"=> [Hash("severity"=>"fatal"), Hash("severity"=>"info")])]) }
    let(:results_green_status) { Hash("files"=> [Hash("offenses"=> []), Hash("offenses"=> [])]) }

    before do
      allow(subject).to receive(:fq_repo_name).and_return(repo)
      allow(subject).to receive(:pr_number).and_return(num)
      allow(subject).to receive(:rubocop_comments).and_return(comments)
      allow(subject).to receive(:commits).and_return(commits)
    end

    after do
      subject.send(:replace_rubocop_comments)
    end

    it "should call replace_comments with :zero (green - success) status" do
      allow(subject).to receive(:results).and_return(results_green_status)

      expect(GithubService).to receive(:replace_comments).with(repo, num, comments, :zero, sha).once
    end

    it "should call replace_comments with :bomb (red - error) status" do
      allow(subject).to receive(:results).and_return(results_red_status)

      expect(GithubService).to receive(:replace_comments).with(repo, num, comments, :bomb, sha).once
    end

    it "should call replace_comments with :warn (green - success) status" do
      allow(subject).to receive(:results).and_return(results_no_status)

      expect(GithubService).to receive(:replace_comments).with(repo, num, comments, :warn, sha).once
    end
  end
end
