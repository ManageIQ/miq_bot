describe PullRequestMonitor do
  describe "#process_repo" do
    let(:repo)   { create(:repo) }
    let(:github) { stub_github_service }

    let(:github_pr_head_repo) { double("Github repo", :html_url => "https://github.com/SomeUser/some_repo") }
    let(:github_pr) do
      double("Github PR",
        :number => 1,
        :title  => "PR number 1",

        :base => double("Github PR base",
          :ref  => "master",
          :repo => double("Github repo", :html_url => "https://github.com/#{repo.name}")
        ),

        :head => double("Github PR head",
          :repo => github_pr_head_repo
        )
      )
    end

    it "ignores a repo that can't have PRs (because of no upstream_user)" do
      repo.update_attributes(:name => "foo")

      expect(repo).to_not receive(:synchronize_pr_branches)

      described_class.new.process_repo(repo)
    end

    it "with Github PRs" do
      stub_github_prs(github, github_pr)

      expect(repo).to receive(:synchronize_pr_branches).with([{
        :number       => 1,
        :html_url     => "https://github.com/SomeUser/some_repo",
        :merge_target => "master",
        :pr_title     => "PR number 1"
      }])

      described_class.new.process_repo(repo)
    end

    context "when the Github PR head.repo is nil" do
      let(:github_pr_head_repo) { nil }

      it "creates a PR branch" do
        stub_github_prs(github, github_pr)

        expect(repo).to receive(:synchronize_pr_branches).with([{
          :number       => 1,
          :html_url     => "https://github.com/#{repo.name}",
          :merge_target => "master",
          :pr_title     => "PR number 1"
        }])

        described_class.new.process_repo(repo)
      end
    end

    it "when there are no Github PRs" do
      stub_github_prs(github, [])

      expect(repo).to receive(:synchronize_pr_branches).with([])

      described_class.new.process_repo(repo)
    end
  end
end
