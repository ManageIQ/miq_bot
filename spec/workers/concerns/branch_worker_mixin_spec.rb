require 'spec_helper'

describe BranchWorkerMixin do
  subject do
    Class.new do
      include BranchWorkerMixin

      def self.name
        "TestModule::TestClass"
      end

      def logger
        @logger ||= RSpec::Mocks::Double.new("logger")
      end
    end.new
  end
  let(:repo)      { Repo.create!(:name => "some_repo", :upstream_user => "SomeUser", :path => "xxx") }
  let(:branch)    { Branch.create!(:name => "master", :last_commit => "xxx", :commit_uri => "xxx", :repo => repo) }
  let(:pr_branch) { Branch.create!(:name => "pr/1",   :last_commit => "xxx", :commit_uri => "xxx", :repo => repo, :pull_request => true) }

  describe "#find_branch" do
    context "without required_mode" do
      it "with an existing branch" do
        expect(subject.find_branch(branch.id)).to be true
      end

      it "with a missing branch" do
        expect(subject.logger).to receive(:warn) do |message|
          expect(message).to match(/no longer exists/)
        end
        expect(subject.find_branch(-1)).to be false
      end
    end

    context "with required_mode" do
      it "with a regular branch" do
        expect(subject.find_branch(branch.id, :regular)).to be true
      end

      it "with a regular branch, but requiring a PR branch" do
        expect(subject.logger).to receive(:error) do |message|
          expect(message).to match(/is not a pr branch/)
        end
        expect(subject.find_branch(branch.id, :pr)).to be false
      end

      it "with a PR branch" do
        expect(subject.find_branch(pr_branch.id, :pr)).to be true
      end

      it "with a PR branch, but requiring a regular branch" do
        expect(subject.logger).to receive(:error) do |message|
          expect(message).to match(/is not a regular branch/)
        end
        expect(subject.find_branch(pr_branch.id, :regular)).to be false
      end
    end
  end

  it "#pr_number" do
    subject.find_branch(pr_branch.id)

    expect(subject.pr_number).to eq(1)
  end

  it "#commits" do
    pr_branch.update_attributes(:commits_list => %w(a b c))
    subject.find_branch(pr_branch.id)

    expect(subject.commits).to eq(%w(a b c))
  end

  it "#commit_range" do
    pr_branch.update_attributes(:commits_list => %w(a b c))
    subject.find_branch(pr_branch.id)

    expect(subject.commit_range).to eq(%w(a c))
  end

  describe "#branch_enabled?" do
    it "when enabled" do
      stub_settings(:test_class, :enabled_repos, ["SomeUser/some_repo"])
      subject.find_branch(pr_branch.id)

      expect(subject.branch_enabled?).to be true
    end

    it "when disabled" do
      stub_settings(:test_class, :enabled_repos, [])
      subject.find_branch(pr_branch.id)

      expect(subject.branch_enabled?).to be false
    end
  end

  describe "#verify_branch_enabled" do
    it "when enabled" do
      stub_settings(:test_class, :enabled_repos, ["SomeUser/some_repo"])
      subject.find_branch(pr_branch.id)

      expect(subject.verify_branch_enabled).to be true
    end

    it "when disabled" do
      stub_settings(:test_class, :enabled_repos, [])
      subject.find_branch(pr_branch.id)

      expect(subject.logger).to receive(:warn) do |message|
        expect(message).to match(/has not been enabled/)
      end
      expect(subject.verify_branch_enabled).to be false
    end
  end
end
