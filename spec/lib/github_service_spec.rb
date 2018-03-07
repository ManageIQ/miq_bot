describe GithubService do
  let(:repo) { "owner/repository" }
  let(:sha) { "b0e6911a4b7cc8dcf6aa4ed28244a1d5fb90d051" }
  let(:url) { "https://github.com/" }
  let(:num) { 42 }

  describe "#username_lookup" do
    let(:lookup_username) { "NickLaMuro" }
    let(:lookup_status)   { 200 }

    before do
      # HTTP lookup
      stub_request(:head, "https://github.com/#{lookup_username}")
        .with(:headers => {'Accept' => '*/*', 'User-Agent' => 'Ruby'})
        .to_return(:status => lookup_status, :body => "", :headers => {})
    end

    after do
      lookup_cache.delete(lookup_username)
    end

    def lookup_cache
      described_class.send(:username_lookup_cache)
    end

    context "for a valid user" do
      before do
        github_service_add_stub :url           => "/users/#{lookup_username}",
                                :response_body => {'id' => 123}.to_json
      end

      it "looks up a user and stores the user's ID in the cache" do
        expect(described_class.username_lookup(lookup_username)).to eq(123)
        expect(lookup_cache).to eq("NickLaMuro" => 123)
      end
    end

    context "for a user that is not found" do
      let(:lookup_status) { 404 }

      it "looks up a user and stores the user's ID in the cache" do
        expect(described_class.username_lookup(lookup_username)).to eq(nil)
        expect(lookup_cache).to eq("NickLaMuro" => nil)
      end

      it "does a lookup call only once" do
        http_instance  = Net::HTTP.new("github.com", 443)
        fake_not_found = Net::HTTPNotFound.new(nil, nil, nil)
        expect(Net::HTTP).to     receive(:new).and_return(http_instance)
        expect(http_instance).to receive(:request_head).once.and_return(fake_not_found)

        expect(described_class.username_lookup(lookup_username)).to eq(nil)
        expect(described_class.username_lookup(lookup_username)).to eq(nil)
      end
    end

    context "when GitHub is having a bad time..." do
      let(:lookup_status) { 500 }

      it "looks up a user and does not stores the username in the cache" do
        expect do
          described_class.username_lookup(lookup_username)
        end.to raise_error(RuntimeError, "Error on GitHub with username lookup")
        expect(lookup_cache).to eq({})
      end
    end
  end

  describe ".add_status" do
    let(:username) { "name" }

    before do
      stub_settings(Hash(:github_credentials => {:username => username}))
    end

    it "should create a success state (zero offenses)" do
      expect(described_class).to receive(:create_status).with(repo, sha, "success", Hash("context" => username, "target_url" => url, "description" => "Everything looks fine."))

      described_class.add_status(repo, sha, url, :zero)
    end

    it "should create an success state (some offenses)" do
      expect(described_class).to receive(:create_status).with(repo, sha, "success", Hash("context" => username, "target_url" => url, "description" => "Some offenses detected."))

      described_class.add_status(repo, sha, url, :warn)
    end

    it "should create an error state (at least one bomb offense)" do
      expect(described_class).to receive(:create_status).with(repo, sha, "error", Hash("context" => username, "target_url" => url, "description" => "Something went wrong."))

      described_class.add_status(repo, sha, url, :bomb)
    end
  end

  describe ".add_comments" do
    let(:comment_in) { "input_comment" }
    let(:comments_in) { [comment_in, comment_in, comment_in] }
    let(:comment_out) { Hash("html_url"=> url) }

    it "should return an array of comments" do
      expect(described_class).to receive(:add_comment).with(repo, num, comment_in).and_return(comment_out).exactly(comments_in.count)
      expect(described_class.add_comments(repo, num, comments_in)).to match_array([comment_out, comment_out, comment_out])
    end
  end

  describe ".replace_comments" do
    let(:comments_in) { %w(input_comment input_comment input_comment) }
    let(:comment_to_delete) { double("comment_to_delete", :id => "comment_id") }
    let(:comments_to_delete) { [comment_to_delete, comment_to_delete, comment_to_delete] }
    let(:comments_out) { [Hash("html_url"=> url), Hash("key"=> "value")] }

    it "should add commit status" do
      expect(described_class).to receive(:issue_comments).with(repo, num).and_return(comments_to_delete)
      expect(described_class).to receive(:delete_comments).with(repo, comments_to_delete.map(&:id))
      expect(described_class).to receive(:add_comments).with(repo, num, comments_in).and_return(comments_out)
      expect(described_class).to receive(:add_status).with(repo, sha, url, true).once

      described_class.replace_comments(repo, num, comments_in, true, sha) { "something" }
    end
  end
end
