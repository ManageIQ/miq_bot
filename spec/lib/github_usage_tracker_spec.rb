describe GithubUsageTracker do
  subject(:tracker) { described_class.new }
  let(:influxdb_client) { double }
  let(:logger) { double(:info) }

  before do
    allow(tracker).to receive(:configured?).and_return(true)
    allow(tracker).to receive(:influxdb).and_return(influxdb_client)
    stub_const("Rails", double(:logger => logger))
    stub_const("MiqBot", double(:version => "test"))
  end

  describe "#record_datapoint" do
    after do
      tracker.record_datapoint(:requests_remaining => 1337, :uri => request_uri)
    end

    context "with full URLs" do
      let(:request_uri) { "https://api.github.com/orgs/ManageIQ" }
      it "parses the URI correctly" do
        expect(influxdb_client).to receive(:write_point)
          .with('github_api_request', a_hash_including(:values => a_hash_including(:uri => "/orgs/ManageIQ")))
      end
    end

    context "with full URLs, trailing slash" do
      let(:request_uri) { "http://custom.githubdomain.com/orgs/ManageIQ/" }
      it "parses the URI correctly" do
        expect(influxdb_client).to receive(:write_point)
          .with('github_api_request', a_hash_including(:values => a_hash_including(:uri => "/orgs/ManageIQ")))
      end
    end

    context "with URI paths" do
      let(:request_uri) { "/orgs/ManageIQ" }
      it "parses the URI correctly" do
        expect(influxdb_client).to receive(:write_point)
          .with('github_api_request', a_hash_including(:values => a_hash_including(:uri => "/orgs/ManageIQ")))
      end
    end

    context "with querystring" do
      let(:request_uri) { "https://api.github.com/orgs/ManageIQ?some=thing&other=thing" }
      it "parses the URI correctly" do
        expect(influxdb_client).to receive(:write_point)
          .with('github_api_request', a_hash_including(:values => a_hash_including(:uri => "/orgs/ManageIQ")))
      end
    end

    context "with an invalid URI" do
      let(:request_uri) { nil }
      it "parses the URI correctly" do
        expect(logger).to receive(:info).with(a_string_including("URI::InvalidURIError"))
      end
    end
  end
end
