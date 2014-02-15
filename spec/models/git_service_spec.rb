require 'spec_helper'

describe GitService do
  let(:service) { double("git service") }

  before do
    described_class.any_instance.stub(:service => service)
  end

  def with_service
    described_class.call("/path/to/repo") { |git| yield git }
  end

  it_should_behave_like "ServiceMixin service"

  context "native git method" do
    it "#checkout" do
      expect(service).to receive(:checkout).with("master").and_return("Switched to branch 'master'\n")
      with_service do |git|
        expect(git.checkout("master")).to eq "Switched to branch 'master'"
      end
    end
  end

  it "#new_commits" do
    expect(service).to receive(:rev_list).and_return(<<-EOGIT)
03168b97d19a2f7954e5b29a5cb18862e707ab6c
7575fbbc4919aa64ea34c30102964b6ca6523707
    EOGIT

    with_service do |git|
      expect(git.new_commits("e1512e6acff33bd02c7db928812db8dd8ac4c8d6")).to eq [
        "03168b97d19a2f7954e5b29a5cb18862e707ab6c",
        "7575fbbc4919aa64ea34c30102964b6ca6523707"
      ]
    end
  end

  it "#commit_message" do
    expect(service).to receive(:log).and_return("log_message\n")

    with_service do |git|
      expect(git.commit_message("03168b97d19a2f7954e5b29a5cb18862e707ab6c")).to eq "log_message"
    end
  end

  it "#branches" do
    expect(service).to receive(:branch).and_return(<<-EOGIT)
* master
  branch1
  branch2
    EOGIT

    with_service do |git|
      expect(git.branches).to eq %w{master branch1 branch2}
    end
  end

  it "#current_branch" do
    expect(service).to receive(:rev_parse).and_return("master\n")

    with_service do |git|
      expect(git.current_branch).to eq "master"
    end
  end

  it ".pr_branch" do
    expect(described_class.pr_branch(133)).to eq "pr/133"
  end

  it "#pr_branch" do
    with_service do |git|
      expect(git.pr_branch(133)).to eq "pr/133"
    end
  end

  it ".pr_number" do
    expect(described_class.pr_number("pr/133")).to eq 133
  end

  it "#pr_number" do
    with_service do |git|
      expect(git.pr_number("pr/133")).to eq 133
    end
  end

  context ".pr_branch?" do
    it "with a pr branch" do
      expect(described_class.pr_branch?("pr/133")).to be_true
    end

    it "with a regular branch" do
      expect(described_class.pr_branch?("master")).to be_false
    end
  end

  context "#pr_branch?" do
    it "with pr branch" do
      with_service do |git|
        expect(git.pr_branch?("pr/133")).to be_true
      end
    end

    it "with regular branch" do
      with_service do |git|
        expect(git.pr_branch?("master")).to be_false
      end
    end

    it "with no branch and current branch is a pr branch" do
      described_class.any_instance.stub(:current_branch => "pr/133")
      with_service do |git|
        expect(git.pr_branch?).to be_true
      end
    end

    it "with no branch and current branch is a regular branch" do
      described_class.any_instance.stub(:current_branch => "master")
      with_service do |git|
        expect(git.pr_branch?).to be_false
      end
    end
  end

  context "#update_pr_branch" do
    it "with pr branch" do
      expect(service).to receive(:fetch).with("-fu", "upstream", "refs/pull/133/head:pr/133").and_return("\n")
      expect(service).to receive(:reset).with("--hard").and_return("\n")

      with_service { |git| git.update_pr_branch("pr/133") }
    end

    it "with no branch and on a pr branch" do
      described_class.any_instance.stub(:current_branch => "pr/133")
      expect(service).to receive(:fetch).with("-fu", "upstream", "refs/pull/133/head:pr/133").and_return("\n")
      expect(service).to receive(:reset).with("--hard").and_return("\n")

      with_service { |git| git.update_pr_branch }
    end
  end

  context "#create_pr_branch" do
    it "with pr branch" do
      expect(service).to receive(:fetch).with("-fu", "upstream", "refs/pull/133/head:pr/133").and_return("\n")
      expect(service).to receive(:reset).with("--hard").and_return("\n")

      with_service { |git| git.create_pr_branch("pr/133") }
    end
  end
end
