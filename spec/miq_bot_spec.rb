RSpec.describe MiqBot do
  describe ".version" do
    before { MiqBot.instance_variable_set(:@version, nil)  }
    after  { MiqBot.instance_variable_set(:@version, nil)  }

    context "with git dir present" do
      it "returns the version from git describe" do
        expect(described_class).to receive(:`).with("GIT_DIR=#{File.expand_path("..", __dir__)}/.git git describe --tags").and_return("v0.21.2-91-g6800275\n")

        expect(described_class.version).to eq("v0.21.2-91-g6800275")
      end
    end

    context "with git dir not present" do
      let!(:tmpdir) do
        Pathname.new(Dir.mktmpdir("fake_rails_root")).tap do |tmpdir|
          expect(Rails).to receive(:root).at_least(:once).and_return(tmpdir)
        end
      end
      after { FileUtils.rm_rf(tmpdir) }

      it "returns the version constant" do
        expect(described_class.version).to eq("v#{MiqBot::VERSION}")
      end
    end
  end
end
