require 'spec_helper'

describe CommitMonitorRepo do
  context ".path=" do
    let(:repo) { CommitMonitorRepo.new }
    let(:home) { File.expand_path("~") }

    it "with expanded path" do
      repo.path = "~/path"
      expect(repo.path).to eq File.join(home, "path")
    end

    it "with unexpanded path" do
      repo.path = "/Users/me/path"
      expect(repo.path).to eq "/Users/me/path"
    end
  end
end
