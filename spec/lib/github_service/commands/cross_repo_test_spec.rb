require 'spec_helper'

RSpec.shared_context "with stub cross_repo_tests", :with_stub_cross_repo do
  require 'tmpdir'
  require 'fileutils'

  attr_reader :sandbox_dir, :cross_repo_remote, :cross_repo_clone

  let(:suite_sandbox_dir)        { Rails.root.join("spec", "tmp", "sandbox").to_s }
  let(:github_workflow_yml_path) { File.join(cross_repo_clone, ".github/workflow/ci.yaml") }

  before do |example|
    FileUtils.mkdir_p suite_sandbox_dir

    # Generate a directory for this particular test
    dir_name     = example.full_description.tr(':#', '-').tr(' ', '_')
    @sandbox_dir = Dir.mktmpdir(dir_name, suite_sandbox_dir)

    # Define the dir variables so they are accessible from the examples
    @cross_repo_source = File.join(@sandbox_dir, "cross_repo-tests-source")
    @cross_repo_remote = File.join(@sandbox_dir, "cross_repo-tests-remote")
    @cross_repo_clone  = File.join(@sandbox_dir, "cross_repo-tests-cloned")

    # Set the bot name
    allow(described_class).to receive(:bot_name).and_return("rspec_bot")
    # Set RunTest.test_repo_url to the tmp git dir we are creating
    allow(described_class).to receive(:test_repo_url).and_return(@cross_repo_remote)
    # Set RunTest.test_repo_name to the basename of @cross_repo_clone
    allow(described_class).to receive(:test_repo_name).and_return(File.basename(@cross_repo_clone))
    # Stub Repo::BASE_PATH so that RunTest.test_repo_clone_dir points to the
    # top level of our suite sandbox dir.  The cloned repo will be will be
    # placed into `@sandbox_dir` because of how the code parses the
    # test_repo_url stubbed above.
    stub_const("::Repo::BASE_PATH", Pathname.new(suite_sandbox_dir))

    default_github_workflow_yaml_content = <<~YAML
      name: Cross Repo Tests

      on: [push, pull_request]

      jobs:
        manageiq:
          uses: agrare/manageiq-cross_repo/.github/workflows/manageiq_cross_repo.yaml@github_actions
          with:
            test-repos: '["ManageIQ/manageiq@master"]'
            repos: ManageIQ/manageiq@master
    YAML

    tmp_repo = GitRepoHelper::TmpRepo.generate @cross_repo_source do
      add_file ".github/workflows/ci.yaml", default_github_workflow_yaml_content
      commit "add .github/workflows/ci.yaml"
      tag "v1.0"
    end

    tmp_repo.create_remote "origin", @cross_repo_remote
  end

  # delete tmp repos dir
  after do
    FileUtils.remove_entry sandbox_dir unless ENV["DEBUG"]
    described_class.instance_variable_set(:@test_repo_clone_dir, nil)
  end
end

RSpec.describe GithubService::Commands::CrossRepoTest do
  subject { described_class.new(issue) }

  let(:issue)            { GithubService.issue(fq_repo_name, issue_id) }
  let(:issue_id)         { 1234 }
  let(:issue_url)        { "/repos/#{fq_repo_name}/issues/#{issue_id}" }
  let(:issue_identifier) { "#{fq_repo_name}##{issue_id}" }
  let(:fq_repo_name)     { "ManageIQ/bar" }
  let(:command_issuer)   { "NickLaMuro" }
  let(:command_value)    { "manageiq-ui-classic" }
  let(:comment_url)      { "/repos/#{fq_repo_name}/issues/#{issue_id}/comments" }
  let(:member_check_url) { "/orgs/ManageIQ/members/#{command_issuer}" }
  let(:repo_check_url)   { "/orgs/ManageIQ/repos" }

  def stub_good_pr_check
    clear_stubs_for!(:get, issue_url)
    github_service_add_stub :url           => issue_url,
                            :response_body => single_pull_request_response(fq_repo_name, issue_id)
  end

  def stub_good_member_check
    clear_stubs_for!(:get, member_check_url)
    github_service_add_stub :url             => member_check_url,
                            :response_status => 204
  end

  def stub_issue_comment(body)
    github_service_add_stub :url           => comment_url,
                            :method        => :post,
                            :request_body  => {"body" => body}.to_json,
                            :response_body => {"id" => 1234}.to_json
  end

  def stub_bad_pr_check
    clear_stubs_for!(:get, issue_url)
    github_service_add_stub :url           => issue_url,
                            :response_body => single_issue_request_response(fq_repo_name, issue_id)
  end

  def stub_bad_member_check
    clear_stubs_for!(:get, member_check_url)
    github_service_add_stub :url             => member_check_url,
                            :response_status => 404
  end

  before do
    stub_good_pr_check
    stub_good_member_check
  end

  describe "#execute!" do
    def assert_execute(valid: true)
      expect(subject).to receive(:run_tests).exactly(valid ? 1 : 0).times

      subject.execute!(:issuer => command_issuer, :value => command_value)

      github_service_stubs.verify_stubbed_calls
    end

    it "is valid" do
      assert_execute(:valid => true)
    end

    it "is invalid when not on a PR" do
      stub_bad_pr_check
      stub_issue_comment("@NickLaMuro 'cross-repo-test(s)' command is only valid on pull requests, ignoring...")

      assert_execute(:valid => false)
    end

    it "is invalid when called by a non-org member" do
      stub_bad_member_check
      stub_issue_comment("@NickLaMuro Only members of the ManageIQ organization may use this command.")

      assert_execute(:valid => false)
    end

    context "with no input" do
      let(:command_value) { "" }

      it "is valid" do
        assert_execute(:valid => true)
      end
    end

    describe "with conflicting repo names" do
      context "in the test repo list" do
        let(:command_value) { "manageiq-ui-classic#1234, manageiq-ui-classic#2345" }

        it "is invalid" do
          stub_issue_comment(<<~COMMENT)
            @NickLaMuro 'cross-repo-test(s)' was given conflicting repo names and cannot continue

            * `ManageIQ/manageiq-ui-classic#1234`, `ManageIQ/manageiq-ui-classic#2345` conflict
          COMMENT

          assert_execute(:valid => false)
        end
      end

      context "in the included repos list" do
        let(:command_value) { "manageiq#1234 including manageiq-ui-classic#1234, manageiq-ui-classic#2345" }

        it "is invalid" do
          stub_issue_comment(<<~COMMENT)
            @NickLaMuro 'cross-repo-test(s)' was given conflicting repo names and cannot continue

            * `ManageIQ/manageiq-ui-classic#1234`, `ManageIQ/manageiq-ui-classic#2345` conflict
          COMMENT

          assert_execute(:valid => false)
        end
      end

      context "across the test repo list and the included repos list" do
        let(:command_value) { "manageiq-ui-classic#1234 including manageiq-ui-classic#2345" }

        it "is invalid" do
          stub_issue_comment(<<~COMMENT)
            @NickLaMuro 'cross-repo-test(s)' was given conflicting repo names and cannot continue

            * `ManageIQ/manageiq-ui-classic#1234`, `ManageIQ/manageiq-ui-classic#2345` conflict
          COMMENT

          assert_execute(:valid => false)
        end
      end

      context "with the PR itself in the test repo list" do
        let(:command_value) { "#2345" }

        it "is invalid" do
          stub_issue_comment(<<~COMMENT)
            @NickLaMuro 'cross-repo-test(s)' was given conflicting repo names and cannot continue

            * `ManageIQ/bar#1234`, `ManageIQ/bar#2345` conflict
          COMMENT

          assert_execute(:valid => false)
        end
      end

      context "with the PR itself in the included repos list" do
        let(:command_value) { "manageiq-ui-classic including #2345" }

        it "is invalid" do
          stub_issue_comment(<<~COMMENT)
            @NickLaMuro 'cross-repo-test(s)' was given conflicting repo names and cannot continue

            * `ManageIQ/bar#1234`, `ManageIQ/bar#2345` conflict
          COMMENT

          assert_execute(:valid => false)
        end
      end

      context "with multiple conflicts in test repos list" do
        let(:command_value) { "manageiq-ui-classic#1234, manageiq-ui-classic#2345, manageiq-api#1234, manageiq-api#2345" }

        it "is invalid" do
          stub_issue_comment(<<~COMMENT)
            @NickLaMuro 'cross-repo-test(s)' was given conflicting repo names and cannot continue

            * `ManageIQ/manageiq-api#1234`, `ManageIQ/manageiq-api#2345` conflict
            * `ManageIQ/manageiq-ui-classic#1234`, `ManageIQ/manageiq-ui-classic#2345` conflict
          COMMENT

          assert_execute(:valid => false)
        end
      end

      context "with multiple conflicts in included repos list" do
        let(:command_value) { "manageiq#1234 including manageiq-ui-classic#1234, manageiq-ui-classic#2345, manageiq-api#1234, manageiq-api#2345" }

        it "is invalid" do
          stub_issue_comment(<<~COMMENT)
            @NickLaMuro 'cross-repo-test(s)' was given conflicting repo names and cannot continue

            * `ManageIQ/manageiq-api#1234`, `ManageIQ/manageiq-api#2345` conflict
            * `ManageIQ/manageiq-ui-classic#1234`, `ManageIQ/manageiq-ui-classic#2345` conflict
          COMMENT

          assert_execute(:valid => false)
        end
      end

      context "with multiple conflicts across the test repo list and the included repos list" do
        let(:command_value) { "manageiq-ui-classic#1234, manageiq-ui-classic#2345 including manageiq-api#1234, manageiq-api#2345" }

        it "is invalid" do
          stub_issue_comment(<<~COMMENT)
            @NickLaMuro 'cross-repo-test(s)' was given conflicting repo names and cannot continue

            * `ManageIQ/manageiq-api#1234`, `ManageIQ/manageiq-api#2345` conflict
            * `ManageIQ/manageiq-ui-classic#1234`, `ManageIQ/manageiq-ui-classic#2345` conflict
          COMMENT

          assert_execute(:valid => false)
        end
      end
    end

    context "with an unknown repo" do
      let(:command_value) { "fake-repo" }

      # We have determined that the bot doesn't need to validate this, and it
      # will just fail on CI instead of trying to fail early here.
      #
      # We also lock down by org, so we don't need to handle for this command
      # being abused.
      it "it is still valid" do
        assert_execute(:valid => true)
      end
    end
  end

  describe "#run_tests", :with_stub_cross_repo do
    before do
      subject.instance_variable_set(:@issuer,     command_issuer)
      subject.instance_variable_set(:@repos,      %w[repo1 repo2])
      subject.instance_variable_set(:@test_repos, %w[foo bar])

      clear_previous_github_service_stubs!

      pull_request_data = {
        "base"  => "master",
        "head"  => subject.branch_name,
        "title" => "[BOT] Cross repo test for ManageIQ/bar#1234",
        "body"  => <<~PR_BODY
          From Pull Request:  ManageIQ/bar#1234
          For User:           @NickLaMuro
        PR_BODY
      }.to_json

      github_service_add_stub :url           => "/repos/ManageIQ/cross_repo-tests-remote/pulls",
                              :method        => :post,
                              :request_body  => pull_request_data,
                              :response_body => {"number" => 2345}.to_json

      my_email = "NickLaMuro@example.com"
      github_service_add_stub :url           => "/users/NickLaMuro",
                              :response_body => {"email" => my_email}.to_json

      subject.run_tests
    end

    it "clones the repo as a bare repo" do
      expect(Dir.exist?(cross_repo_clone)).to be_truthy
      expect(File.exist?(github_workflow_yml_path)).to be_falsey
    end

    it "creates a new branch (stays on master)" do
      branch = subject.branch_name
      repo   = subject.rugged_repo

      expect(repo.branches.map(&:name)).to include branch
      expect(repo.head.name.sub(/^refs\/heads\//, '')).to eq "master"
    end

    it "updates the .github/workflows/ci.yaml" do
      repo                        = subject.rugged_repo
      branch                      = repo.branches["origin/#{subject.branch_name}"]
      github_workflow_yml_content = repo.blob_at(branch.target.oid, ".github/workflows/ci.yaml").content
      content                     = YAML.safe_load(github_workflow_yml_content)

      expect(content["jobs"]["cross-repo"]["with"]["test-repos"]).to eq('["foo", "bar"]')
      expect(content["jobs"]["cross-repo"]["with"]["repos"]).to eq("repo1,repo2")
    end

    it "commits the changes" do
      repo   = subject.rugged_repo
      commit = repo.branches[subject.branch_name].target

      expect(commit.author[:name]).to     eq("NickLaMuro")
      expect(commit.author[:email]).to    eq("NickLaMuro@example.com")
      expect(commit.committer[:name]).to  eq("rspec_bot")
      expect(commit.committer[:email]).to eq("no_bot_email@example.com")

      commit_content = repo.blob_at(commit.oid, ".github/workflows/ci.yaml").content

      expect(commit.message).to eq <<~MSG
        Running tests for NickLaMuro

        From Pull Request:  ManageIQ/bar#1234
      MSG

      expect(commit_content).to include "repos: repo1,repo2"
      expect(commit_content).to include "test-repos: '[\"foo\", \"bar\"]'"
    end

    it "pushes the changes" do
      Dir.mktmpdir do |dir|
        # create a new clone to test the remote got the push
        repo = Rugged::Repository.clone_at cross_repo_remote, dir
        repo.remotes["origin"].fetch

        branch_name    = subject.branch_name # branch name from cloned repo
        branch         = repo.branches["origin/#{branch_name}"]
        commit_content = repo.blob_at(branch.target.oid, ".github/workflows/ci.yaml").content

        expect(branch).to_not be_nil
        expect(branch.target.message).to eq <<~MSG
          Running tests for NickLaMuro

          From Pull Request:  ManageIQ/bar#1234
        MSG

        expect(commit_content).to include "repos: repo1,repo2"
        expect(commit_content).to include "test-repos: '[\"foo\", \"bar\"]'"
      end
    end

    it "creates a pull request" do
      github_service_stubs.verify_stubbed_calls
    end
  end

  describe "#parse_value (private)" do
    let(:repo_groups_hash) { {"providers" => ["manageiq-providers-amazon", "manageiq-providers-azure"]} }

    before do
      allow(described_class).to receive(:repo_groups_hash).and_return(repo_groups_hash)
      subject.send(:parse_value, command_value)
    end

    it "sets @test_repos and @repos" do
      expect(subject.test_repos).to eq ["ManageIQ/manageiq-ui-classic", issue_identifier].sort
      expect(subject.repos).to      eq [issue_identifier]
    end

    context "without 'including' argument" do
      let(:command_value) { "manageiq-ui-classic#1234, manageiq-api" }

      it "sets @test_repos and @repos" do
        expect(subject.test_repos).to eq ["ManageIQ/manageiq-api", "ManageIQ/manageiq-ui-classic#1234", issue_identifier].sort
        expect(subject.repos).to      eq ["ManageIQ/manageiq-ui-classic#1234", issue_identifier].sort
      end
    end

    context "without any args" do
      let(:command_value) { "" }

      it "sets @test_repos and @repos" do
        expect(subject.test_repos).to eq [issue_identifier].sort
        expect(subject.repos).to      eq [issue_identifier].sort
      end
    end

    context "with 'including' argument" do
      let(:command_value) { "manageiq-ui-classic#1234, manageiq-api including manageiq#2345" }

      it "sets @test_repos and @repos" do
        expect(subject.test_repos).to eq ["ManageIQ/manageiq-api", "ManageIQ/manageiq-ui-classic#1234", issue_identifier].sort
        expect(subject.repos).to      eq ["ManageIQ/manageiq#2345", "ManageIQ/manageiq-ui-classic#1234", issue_identifier].sort
      end
    end

    context "with 'includes' argument" do
      let(:command_value) { "manageiq-ui-classic#1234, manageiq-api includes manageiq#2345" }

      it "sets @test_repos and @repos" do
        expect(subject.test_repos).to eq ["ManageIQ/manageiq-api", "ManageIQ/manageiq-ui-classic#1234", issue_identifier].sort
        expect(subject.repos).to      eq ["ManageIQ/manageiq#2345", "ManageIQ/manageiq-ui-classic#1234", issue_identifier].sort
      end
    end

    context "with 'including' argument that is also listed as a test_repo" do
      let(:command_value) { "manageiq-ui-classic#1234, manageiq-api including manageiq-ui-classic#1234" }

      it "sets @test_repos and @repos" do
        expect(subject.test_repos).to eq ["ManageIQ/manageiq-api", "ManageIQ/manageiq-ui-classic#1234", issue_identifier].sort
        expect(subject.repos).to      eq ["ManageIQ/manageiq-ui-classic#1234", issue_identifier].sort
      end
    end

    context "with repo groups" do
      context "with just /providers group" do
        let(:command_value) { "/providers" }

        it "sets @test_repos and @repos" do
          expect(subject.test_repos).to eq ["ManageIQ/manageiq-providers-amazon", "ManageIQ/manageiq-providers-azure", issue_identifier].sort
          expect(subject.repos).to      eq [issue_identifier]
        end
      end

      context "with /providers group and including" do
        let(:command_value) { "/providers including manageiq#1234" }

        it "sets @test_repos and @repos" do
          expect(subject.test_repos).to eq ["ManageIQ/manageiq-providers-amazon", "ManageIQ/manageiq-providers-azure", issue_identifier].sort
          expect(subject.repos).to      eq ["ManageIQ/manageiq#1234", issue_identifier].sort
        end
      end

      context "with a test PR and a group" do
        let(:command_value) { "manageiq-providers-amazon#1234, /providers including manageiq#1234" }

        it "sets @test_repos and @repos" do
          expect(subject.test_repos).to eq ["ManageIQ/manageiq-providers-amazon#1234", "ManageIQ/manageiq-providers-azure", issue_identifier].sort
          expect(subject.repos).to      eq ["ManageIQ/manageiq#1234", "ManageIQ/manageiq-providers-amazon#1234", issue_identifier].sort
        end
      end

      context "with a test repo that contains a substring of a provider group" do
        let(:command_value) { "manageiq-providers-azure_stack#1234, /providers including manageiq#1234" }

        it "sets @test_repos and @repos" do
          expect(subject.test_repos).to eq ["ManageIQ/manageiq-providers-amazon", "ManageIQ/manageiq-providers-azure", "ManageIQ/manageiq-providers-azure_stack#1234", issue_identifier].sort
          expect(subject.repos).to      eq ["ManageIQ/manageiq#1234", "ManageIQ/manageiq-providers-azure_stack#1234", issue_identifier].sort
        end
      end
    end

    context "with URLs" do
      context "in a test repo" do
        let(:command_value) { "https://github.com/ManageIQ/manageiq/pull/1234" }

        it "sets @test_repos and @repos" do
          expect(subject.test_repos).to eq ["ManageIQ/manageiq#1234", issue_identifier].sort
          expect(subject.repos).to      eq ["ManageIQ/manageiq#1234", issue_identifier].sort
        end
      end

      context "in included repos" do
        let(:command_value) { "manageiq-api including https://github.com/ManageIQ/manageiq/pull/1234" }

        it "sets @test_repos and @repos" do
          expect(subject.test_repos).to eq ["ManageIQ/manageiq-api", issue_identifier].sort
          expect(subject.repos).to      eq ["ManageIQ/manageiq#1234", issue_identifier].sort
        end
      end
    end

    context "multiple repos and test repos" do
      let(:repos)         { %w[Fryguy/more_core_extensions@feature linux_admin#123] }
      let(:test_repos)    { %w[manageiq-api manageiq-ui-classic] }

      let(:expected_test_repos) do
        ["ManageIQ/manageiq-api", "ManageIQ/manageiq-ui-classic", issue_identifier].sort
      end
      let(:expected_repos) do
        ["Fryguy/more_core_extensions@feature", "ManageIQ/linux_admin#123", issue_identifier].sort
      end

      context "with no spaces" do
        let(:command_value) { "#{test_repos.join(',')} including #{repos.join(',')}" }

        it "sets @test_repos and @repos" do
          expect(subject.test_repos).to eq expected_test_repos
          expect(subject.repos).to      eq expected_repos
        end
      end

      context "with only spaces" do
        let(:command_value) { "#{test_repos.join(' ')} including #{repos.join(' ')}" }

        it "sets @test_repos and @repos" do
          expect(subject.test_repos).to eq expected_test_repos
          expect(subject.repos).to      eq expected_repos
        end
      end

      context "with spaces after commas" do
        let(:command_value) { "#{test_repos.join(', ')} including #{repos.join(', ')}" }

        it "sets @test_repos and @repos" do
          expect(subject.test_repos).to eq expected_test_repos
          expect(subject.repos).to      eq expected_repos
        end
      end
    end

    context "with duplicates" do
      context "in the test repos with different normalizations" do
        let(:command_value) { "ManageIQ/manageiq-api, manageiq-api" }

        it "de-dups" do
          expect(subject.test_repos).to eq ["ManageIQ/manageiq-api", issue_identifier].sort
          expect(subject.repos).to      eq [issue_identifier]
        end
      end

      context "where the test repos has both a bare repo and a PR" do
        let(:command_value) { "ManageIQ/manageiq-api#1234, manageiq-api" }

        it "de-dups" do
          expect(subject.test_repos).to eq ["ManageIQ/manageiq-api#1234", issue_identifier].sort
          expect(subject.repos).to      eq ["ManageIQ/manageiq-api#1234", issue_identifier].sort
        end
      end

      context "across the test repos and the included repos" do
        let(:command_value) { "ManageIQ/manageiq-api including manageiq-api#1234" }

        it "de-dups" do
          expect(subject.test_repos).to eq ["ManageIQ/manageiq-api#1234", issue_identifier].sort
          expect(subject.repos).to      eq ["ManageIQ/manageiq-api#1234", issue_identifier].sort
        end
      end

      context "where the included repos has the PR itself" do
        let(:command_value) { "ManageIQ/manageiq-api including bar#1234" }

        it "de-dups" do
          expect(subject.test_repos).to eq ["ManageIQ/manageiq-api", issue_identifier].sort
          expect(subject.repos).to      eq [issue_identifier]
        end
      end

      context "where the test repos has a bare repo of the PR itself" do
        let(:command_value) { "ManageIQ/manageiq-api, bar" }

        it "de-dups" do
          expect(subject.test_repos).to eq ["ManageIQ/manageiq-api", issue_identifier].sort
          expect(subject.repos).to      eq [issue_identifier].sort
        end
      end

      context "where the test repos has a repo group that will collide with a bare repo" do
        let(:command_value) { "/providers, manageiq-providers-amazon" }

        it "de-dups" do
          expect(subject.test_repos).to eq ["ManageIQ/manageiq-providers-amazon", "ManageIQ/manageiq-providers-azure", issue_identifier].sort
          expect(subject.repos).to      eq [issue_identifier].sort
        end
      end

      context "where the test repos has a repo group that will collide with a PR" do
        let(:command_value) { "/providers, manageiq-providers-amazon#1234" }

        it "de-dups" do
          expect(subject.test_repos).to eq ["ManageIQ/manageiq-providers-amazon#1234", "ManageIQ/manageiq-providers-azure", issue_identifier].sort
          expect(subject.repos).to      eq ["ManageIQ/manageiq-providers-amazon#1234", issue_identifier].sort
        end
      end

      context "where the test repos has a repo group that will collide with an included repo" do
        let(:command_value) { "/providers including manageiq-providers-amazon#1234" }

        it "de-dups" do
          expect(subject.test_repos).to eq ["ManageIQ/manageiq-providers-amazon#1234", "ManageIQ/manageiq-providers-azure", issue_identifier].sort
          expect(subject.repos).to      eq ["ManageIQ/manageiq-providers-amazon#1234", issue_identifier].sort
        end
      end

      context "where the test repos has a URL that will collide with a PR" do
        let(:command_value) { "manageiq#1234, https://github.com/ManageIQ/manageiq/pull/1234" }

        it "sets @test_repos and @repos" do
          expect(subject.test_repos).to eq ["ManageIQ/manageiq#1234", issue_identifier].sort
          expect(subject.repos).to      eq ["ManageIQ/manageiq#1234", issue_identifier].sort
        end
      end

      context "where the test repos has a URL that will collide with an included repo" do
        let(:command_value) { "https://github.com/ManageIQ/manageiq/pull/1234 including manageiq#1234" }

        it "sets @test_repos and @repos" do
          expect(subject.test_repos).to eq ["ManageIQ/manageiq#1234", issue_identifier].sort
          expect(subject.repos).to      eq ["ManageIQ/manageiq#1234", issue_identifier].sort
        end
      end

      context "where the test repos has a URL that will collide with a repo group" do
        let(:command_value) { "https://github.com/ManageIQ/manageiq-providers-amazon/pull/1234, /providers" }

        it "sets @test_repos and @repos" do
          expect(subject.test_repos).to eq ["ManageIQ/manageiq-providers-amazon#1234", "ManageIQ/manageiq-providers-azure", issue_identifier].sort
          expect(subject.repos).to      eq ["ManageIQ/manageiq-providers-amazon#1234", issue_identifier].sort
        end
      end
    end
  end

  describe "repo_groups_hash" do
    let(:net_http_response) { double("Net::HTTPResponse") }
    before { expect(Net::HTTP).to receive(:get_response).and_return(net_http_response) }

    it "loads simple yaml" do
      yaml = "---\nall:\n  manageiq:\n"

      allow(net_http_response).to receive(:value).and_return(nil)
      allow(net_http_response).to receive(:body).and_return(yaml)

      expect(described_class.repo_groups_hash).to eq({"all" => ["manageiq"]})
    end

    it "loads yaml aliases" do
      yaml = "---\ncore: &core\n  manageiq:\nproviders: &providers\n  manageiq-providers-amazon:\nall:\n  <<: *core\n  <<: *providers\n"
      allow(net_http_response).to receive(:value).and_return(nil)
      allow(net_http_response).to receive(:body).and_return(yaml)

      expect(described_class.repo_groups_hash["all"]).to include("manageiq", "manageiq-providers-amazon")
    end

    it "returns an empty hash on a Net::HTTP failure" do
      allow(net_http_response).to receive(:value).and_raise(Net::HTTPServerException)
      expect(described_class.repo_groups_hash).to eq({})
    end
  end
end
