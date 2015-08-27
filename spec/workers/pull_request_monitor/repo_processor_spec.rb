require "spec_helper"

RSpec.describe PullRequestMonitor::RepoProcessor do
  describe ".process" do
    let(:github) { stub_github_service }
    let(:git) do
      stub_git_service.tap do |git|
        expect(git).to receive(:checkout).with("master")
        expect(git).to receive(:pull)
      end
    end

    def stub_github_prs(prs)
      github_prs = double("Github collection", :all => prs)
      expect(github).to receive(:pull_requests).and_return(github_prs).twice
    end

    it "creates a PR branch record" do
      repo = create(:repo)
      pr   = double("GitHub PR", :number => 1)
      stub_github_prs([pr])

      expect(PullRequestMonitor::PrBranchRecord).to receive(:create).with(git, repo, pr, "pr/1")

      described_class.process(git, repo)
    end

    it "skips an existing PR branch record" do
      repo      = create(:repo, :branches => [create(:pr_branch)])
      pr_number = repo.pr_branches.first.pr_number
      pr        = double("GitHub PR old", :number => pr_number)
      stub_github_prs([pr])

      expect(PullRequestMonitor::PrBranchRecord).to_not receive(:create)

      described_class.process(git, repo)
    end

    it "prunes stale PR branch record" do
      repo      = create(:repo, :branches => [create(:pr_branch)])
      pr_number = repo.pr_branches.first.pr_number
      stub_github_prs([])

      expect(git).to receive(:checkout).with("master") # again
      expect(git).to receive(:destroy_branch).with("pr/#{pr_number}")

      described_class.process(git, repo)
    end
  end
end
