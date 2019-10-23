RSpec.describe GithubService::Commands::RunTests do
  # subject { described_class.new(issue) }
  let(:issue) { double(:fq_repo_name => "foo/bar") }
  let(:issuer) { "chessbyte" }

  # before do
  #   allow(GithubService).to receive(:valid_assignee?).with("foo/bar", "gooduser") { true }
  #   allow(GithubService).to receive(:valid_assignee?).with("foo/bar", "baduser") { false }
  # end

  # after do
  #   subject.execute!(:issuer => command_issuer, :value => command_value)
  # end

  # context "with a valid user" do
  #   let(:command_value) { "gooduser" }

  #   it "assigns to that user" do
  #     expect(issue).to receive(:assign).with("gooduser")
  #   end
  # end

  # context "with an invalid user" do
  #   let(:command_value) { "baduser" }

  #   it "does not assign, reports failure" do
  #     expect(issue).not_to receive(:assign)
  #     expect(issue).to receive(:add_comment).with("@#{command_issuer} 'baduser' is an invalid assignee, ignoring...")
  #   end
  # end

  describe "create_pr" do
    it "stuff" do
      stub_request(:get, "https://api.github.com/repos/ManageIQ/manageiq-ui-classic").
        with(headers: {'Accept'=>'application/vnd.github.v3+json', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Content-Type'=>'application/json', 'User-Agent'=>'Octokit Ruby Gem 4.8.0'}).
        to_return(status: 200, body: "", headers: {})

         allow(issue).to receive(:as_pull_request).and_return(issue)
         allow(issue).to receive(:number).and_return(2)
         # I have absolutely no idea how to actually test the next line.
         allow(Settings).to receive(:run_tests_repo).and_return(double(:name => "d-m-u/sandbox"))

      expect(described_class.new(issue).send(:create_pr, "ManageIQ/manageiq-ui-classic", issuer)).to eq([["manageiq-ui-classic"],[]])

    end
  end

  describe "extract_repo_names" do
    it "with things" do
      stub_request(:get, "https://api.github.com/repos/ManageIQ/foo").
        with(headers: {'Accept'=>'application/vnd.github.v3+json', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Content-Type'=>'application/json', 'User-Agent'=>'Octokit Ruby Gem 4.8.0'}).
        to_return(status: 404, body: "", headers: {})

      stub_request(:get, "https://api.github.com/repos/ManageIQ/manageiq-ui-classic").
        with(headers: {'Accept'=>'application/vnd.github.v3+json', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Content-Type'=>'application/json', 'User-Agent'=>'Octokit Ruby Gem 4.8.0'}).
        to_return(status: 200, body: "", headers: {})

      expect(described_class.new(issue).send(:extract_repo_names, "ManageIQ/foo, manageiq-ui-classic")).to eq([["manageiq-ui-classic"], ["ManageIQ/foo"]])
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
