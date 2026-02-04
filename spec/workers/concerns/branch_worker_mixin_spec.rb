describe BranchWorkerMixin do
  subject do
    Class.new do
      def self.name
        "TestModule::TestClass"
      end

      include BranchWorkerMixin

      def logger
        @logger ||= RSpec::Mocks::Double.new("logger")
      end
    end.new
  end
  let!(:repo)     { create(:repo, :name => "SomeUser/some_repo") }
  let(:branch)    { create(:branch,    :name => "master", :repo => repo) }
  let(:pr_branch) { create(:pr_branch, :name => "pr/1",   :repo => repo) }

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
    pr_branch.update(:commits_list => %w[a b c])
    subject.find_branch(pr_branch.id)

    expect(subject.commits).to eq(%w[a b c])
  end

  it "#commit_range" do
    pr_branch.update(:commits_list => %w[a b c])
    subject.find_branch(pr_branch.id)

    expect(subject.commit_range).to eq(%w[a c])
  end

  describe "#commit_range_text" do
    it "with a range of commits" do
      pr_branch.update(:commits_list => %w[a b c])
      subject.find_branch(pr_branch.id)

      expect(subject.commit_range_text).to eq("https://example.com/SomeUser/some_repo/compare/a~...c")
    end

    it "with a single commit" do
      pr_branch.update(:commits_list => %w[a])
      subject.find_branch(pr_branch.id)

      expect(subject.commit_range_text).to eq("https://example.com/SomeUser/some_repo/commit/a")
    end
  end

  describe ".enabled_repos" do
    it "raises an exception if both included_repos and excluded_repos are set" do
      stub_settings(:test_class => {:included_repos => ["SomeUser/some_repo"], :excluded_repos => ["SomeUser/some_other_repo"]})
      expect { subject.enabled_repos }.to raise_error(RuntimeError, /Do not specify both/)
    end

    it "with no settings includes all repos" do
      expect(subject.enabled_repos).to eq([repo])
    end

    it "with included_repos" do
      stub_settings(:test_class => {:included_repos => ["SomeUser/some_repo"]})
      expect(subject.enabled_repos).to eq([repo])
    end

    it "with other included_repos" do
      stub_settings(:test_class => {:included_repos => ["SomeUser/some_other_repo"]})
      expect(subject.enabled_repos).to eq([])
    end

    it "with excluded_repos" do
      stub_settings(:test_class => {:excluded_repos => ["SomeUser/some_repo"]})
      expect(subject.enabled_repos).to eq([])
    end

    it "with other excluded_repos" do
      stub_settings(:test_class => {:excluded_repos => ["SomeUser/some_other_repo"]})
      expect(subject.enabled_repos).to eq([repo])
    end
  end

  describe ".enabled_repo_names" do
    it "raises an exception if both included_repos and excluded_repos are set" do
      stub_settings(:test_class => {:included_repos => ["SomeUser/some_repo"], :excluded_repos => ["SomeUser/some_other_repo"]})
      expect { subject.enabled_repo_names }.to raise_error(RuntimeError, /Do not specify both/)
    end

    it "with no settings includes all repos" do
      expect(subject.enabled_repo_names).to eq([repo.name])
    end

    it "with included_repos" do
      stub_settings(:test_class => {:included_repos => ["SomeUser/some_repo"]})
      expect(subject.enabled_repo_names).to eq([repo.name])
    end

    it "with other included_repos" do
      stub_settings(:test_class => {:included_repos => ["SomeUser/some_other_repo"]})
      expect(subject.enabled_repo_names).to eq([])
    end

    it "with excluded_repos" do
      stub_settings(:test_class => {:excluded_repos => ["SomeUser/some_repo"]})
      expect(subject.enabled_repo_names).to eq([])
    end

    it "with other excluded_repos" do
      stub_settings(:test_class => {:excluded_repos => ["SomeUser/some_other_repo"]})
      expect(subject.enabled_repo_names).to eq([repo.name])
    end
  end

  describe ".enabled_for?" do
    it "raises an exception if both included_repos and excluded_repos are set" do
      stub_settings(:test_class => {:included_repos => ["SomeUser/some_repo"], :excluded_repos => ["SomeUser/some_other_repo"]})
      expect { subject.enabled_for?(repo) }.to raise_error(RuntimeError, /Do not specify both/)
    end

    it "with no settings allows all repos" do
      expect(subject.enabled_for?(repo)).to be true
    end

    it "with included_repos" do
      stub_settings(:test_class => {:included_repos => ["SomeUser/some_repo"]})
      expect(subject.enabled_for?(repo)).to be true
    end

    it "with other included_repos" do
      stub_settings(:test_class => {:included_repos => ["SomeUser/some_other_repo"]})
      expect(subject.enabled_for?(repo)).to be false
    end

    it "with excluded_repos" do
      stub_settings(:test_class => {:excluded_repos => ["SomeUser/some_repo"]})
      expect(subject.enabled_for?(repo)).to be false
    end

    it "with other excluded_repos" do
      stub_settings(:test_class => {:excluded_repos => ["SomeUser/some_other_repo"]})
      expect(subject.enabled_for?(repo)).to be true
    end
  end
end
