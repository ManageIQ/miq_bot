RSpec.describe MiqBot do
  describe ".version" do
    before { MiqBot.instance_variable_set(:@version, nil)  }
    after  { MiqBot.instance_variable_set(:@version, nil)  }

    it "with git dir present" do
      expect(described_class).to receive(:`).with("GIT_DIR=#{File.expand_path("..", __dir__)}/.git git describe --tags").and_return("v0.21.2-91-g6800275\n")

      expect(described_class.version).to eq("v0.21.2-91-g6800275")
    end

    context "with git dir not present" do
      let!(:tmpdir) do
        Pathname.new(Dir.mktmpdir("fake_rails_root")).tap do |tmpdir|
          expect(Rails).to receive(:root).at_least(:once).and_return(tmpdir)
        end
      end
      after { FileUtils.rm_rf(tmpdir) }

      context "and VERSION file present" do
        before { tmpdir.join("VERSION").write("v0.21.2-91-g6800275\n") }

        it "returns the content of the VERSION file" do
          expect(described_class.version).to eq("v0.21.2-91-g6800275")
        end
      end

      context "and VERSION file not present" do
        it "returns nothing" do
          expect(described_class.version).to be_empty
        end
      end
    end
  end
end
