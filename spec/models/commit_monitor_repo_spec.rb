require 'spec_helper'

describe CommitMonitorRepo do
  let(:repo) do
    CommitMonitorRepo.new(
      :upstream_user => "some_user",
      :name          => "some_repo"
    )
  end

  it "#fq_name" do
    expect(repo.fq_name).to eq "some_user/some_repo"
  end

  context ".path=" do
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
