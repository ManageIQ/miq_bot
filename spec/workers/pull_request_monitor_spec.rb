describe PullRequestMonitor do
  describe "#process_repo" do
    let(:repo)   { create(:repo) }

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

    def stub_git_service
      expect(repo).to receive(:git_fetch)
      double("Git service", :merge_base => "123abc").tap do |git_service|
        allow_any_instance_of(Branch).to receive(:git_service).and_return(git_service)
      end
    end

    it "ignores a repo that can't have PRs (because of no upstream_user)" do
      repo.update_attributes!(:name => "foo")

      expect(repo).to_not receive(:synchronize_pr_branches)

      described_class.new.process_repo(repo)
    end

    it "with Github PRs" do
      stub_github_prs(github_pr)
      stub_git_service

      expect(repo).to receive(:synchronize_pr_branches).with([{
        :number       => 1,
        :html_url     => "https://github.com/SomeUser/some_repo",
        :merge_target => "master",
        :pr_title     => "PR number 1"
      }]).and_call_original
      expect(PullRequestMonitorHandlers::MergeTargetTitler).to receive(:perform_async)

      described_class.new.process_repo(repo)
    end

    context "when the Github PR head.repo is nil" do
      let(:github_pr_head_repo) { nil }

      it "creates a PR branch" do
        stub_github_prs(github_pr)
        stub_git_service

        expect(repo).to receive(:synchronize_pr_branches).with([{
          :number       => 1,
          :html_url     => "https://github.com/#{repo.name}",
          :merge_target => "master",
          :pr_title     => "PR number 1"
        }]).and_call_original
        expect(PullRequestMonitorHandlers::MergeTargetTitler).to receive(:perform_async)

        described_class.new.process_repo(repo)
      end
    end

    it "when there are no Github PRs" do
      stub_github_prs([])
      stub_git_service

      expect(repo).to receive(:synchronize_pr_branches).with([]).and_call_original
      expect(PullRequestMonitorHandlers::MergeTargetTitler).to_not receive(:perform_async)

      described_class.new.process_repo(repo)
    end
  end
end
