describe GithubService do
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
end
