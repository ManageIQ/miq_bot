RSpec.describe GithubService::Commands::RunTests do
  # subject { described_class.new(issue) }

  let(:issuer) { "chessbyte" }
  let(:repo_path) { Dir.mktmpdir }
  let(:repo_name) { repo_path.split("/").last }
  let(:slug) { "ManageIQ/" + repo_name }
  let(:repo) do
    require 'rugged'
    Rugged::Repository.init_at(repo_path)
  end

  let(:fq_repo_name) { "foo/bar" }
  let(:issue) do
    double('issue',
           :user           => double(:login => "chrisarcand"),
           :body           => "Opened this issue",
           :number         => 1,
           :labels         => [],
           :repository_url => "https://api.fakegithub.com/repos/#{fq_repo_name}")
  end

  subject do
    described_class.new(issue)
  end

  describe "create_pr" do
    it "makes a commit" do
      stub_request(:get, "https://api.github.com/repos/#{slug}/pulls/2")
      .with(headers: {'Accept' => 'application/vnd.github.v3+json', 'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Content-Type' => 'application/json', 'User-Agent' => 'Octokit Ruby Gem 4.8.0'})
      .to_return(:status => 200, :body => "", :headers => {})

      allow(issue).to receive(:as_pull_request).and_return(issue)
      allow(Settings).to receive(:run_tests_repo).and_return(double(:name => "d-m-u/sandbox"))
      allow(issue).to receive(:head).and_return(double(:sha => '222222'))

      expect(subject.send(:create_pr, repo_path, issuer)).to eq([["manageiq-ui-classic"],[]])
    end
  end

  describe "extract_repo_names" do
    it "partitions based on validity" do
      stub_request(:get, "https://api.github.com/repos/ManageIQ/foo")
        .with(headers: {'Accept' => 'application/vnd.github.v3+json', 'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Content-Type' => 'application/json', 'User-Agent' => 'Octokit Ruby Gem 4.8.0'})
        .to_return(:status => 404, :body => "", :headers => {})

      stub_request(:get, "https://api.github.com/repos/ManageIQ/manageiq-ui-classic")
        .with(headers: {'Accept' => 'application/vnd.github.v3+json', 'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Content-Type' => 'application/json', 'User-Agent' => 'Octokit Ruby Gem 4.8.0'})
        .to_return(:status => 200, :body => "", :headers => {})

      expect(described_class.new(issue).send(:extract_repo_names, "ManageIQ/foo, manageiq-ui-classic")).to eq([["manageiq-ui-classic"], ["ManageIQ/foo"]])
    end

    it "should handle # or @ but not both" do
      stub_request(:get, "https://api.github.com/repos/ManageIQ/manageiq")
        .with(headers: {'Accept' => 'application/vnd.github.v3+json', 'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Content-Type' => 'application/json', 'User-Agent' => 'Octokit Ruby Gem 4.8.0'})
        .to_return(:status => 200, :body => "", :headers => {})

      stub_request(:get, "https://api.github.com/repos/ManageIQ/manageiq-ui-classic")
        .with(headers: {'Accept' => 'application/vnd.github.v3+json', 'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Content-Type' => 'application/json', 'User-Agent' => 'Octokit Ruby Gem 4.8.0'})
        .to_return(:status => 200, :body => "", :headers => {})

      expect(described_class.new(issue).send(:extract_repo_names, "ManageIQ/manageiq@1234, manageiq-ui-classic#12345")).to eq([["manageiq@1234", "manageiq-ui-classic#12345"], []])
    end

    it "fails with # and @" do
      stub_request(:get, "https://api.github.com/repos/ManageIQ/manageiq-ui-classic#12345")
        .with(headers: {'Accept' => 'application/vnd.github.v3+json', 'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Content-Type' => 'application/json', 'User-Agent' => 'Octokit Ruby Gem 4.8.0'})
        .to_return(:status => 200, :body => "", :headers => {})

      expect(described_class.new(issue).send(:extract_repo_names, "ManageIQ/manageiq@1234#234, manageiq-ui-classic#12345")).to eq([["manageiq-ui-classic#12345"], ["ManageIQ/manageiq@1234#234"]])
    end
  end

  describe "normalize_repo_name" do
    it "with a full repo name thing" do
      expect(described_class.new(issue).send(:normalize_repo_name, "ManageIQ/foo")).to eq("ManageIQ/foo")
    end

    it "with a partial repo name thing" do
      expect(described_class.new(issue).send(:normalize_repo_name, "foo")).to eq("ManageIQ/foo")
    end
  end
end
