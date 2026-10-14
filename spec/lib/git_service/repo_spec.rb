RSpec.describe GitService::Repo do
  describe "#git_fetch" do
    let(:repo)   { double("Repo", :name => "ManageIQ/miq_bot", :path => "/tmp/does-not-matter") }
    let(:remote) { double("Rugged::Remote", :name => "origin", :url => "https://github.com/ManageIQ/miq_bot.git") }
    let(:rugged) { double("Rugged::Repository", :remotes => [remote]) }

    subject(:service) { described_class.new(repo) }

    before do
      allow(service).to receive(:rugged_repo).and_return(rugged)
      allow(GitService::Credentials).to receive(:find_for_user_and_host).and_return(nil)
    end

    around do |example|
      GC.enable
      example.run
    ensure
      GC.enable
    end

    # Rugged routes libgit2 allocations through Ruby's xmalloc. A GC during a
    # fetch can self-deadlock libgit2's mwindow mutex, so GC must be off.
    it "runs the fetch with GC disabled and re-enables it afterward" do
      gc_disabled_during_fetch = nil
      allow(rugged).to receive(:fetch) do
        gc_disabled_during_fetch = GC.disable
        GC.enable unless gc_disabled_during_fetch
      end

      service.git_fetch

      expect(gc_disabled_during_fetch).to be true
      expect(GC.disable).to be false # GC was re-enabled after the fetch
    end

    it "re-enables GC when the fetch raises" do
      allow(rugged).to receive(:fetch).and_raise(Rugged::NetworkError, "boom")

      expect { service.git_fetch }.to raise_error(Rugged::NetworkError)

      expect(GC.disable).to be false
    end
  end
end
