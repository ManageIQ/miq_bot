require 'spec_helper'

describe GitService do
  let(:service) { double("git service") }

  before do
    GitService.any_instance.stub(:service => service)
  end

  def with_service
    GitService.call("/path/to/repo") { |git| yield git }
  end

  context ".new" do
    it "is private" do
      expect { GitService.new }.to raise_error(NoMethodError)
    end
  end

  context ".call" do
    it "will synchronize multiple callers" do
      t = Thread.new do
        GitService.call("/path/to/repo") do |git|
          Thread.current[:locked] = true
          sleep 0.01 until Thread.current[:release]
        end
      end
      t.abort_on_exception = true
      sleep 0.01 until t[:locked]

      expect(GitService.send(:mutex)).to be_locked

      t[:release] = true
      t.join
    end
  end

  context "native git method" do
    it "#checkout" do
      expect(service).to receive(:checkout).with("master")
      with_service { |git| git.checkout "master" }
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
    expect(service).to receive(:log).and_return("log_message")

    with_service do |git|
      expect(git.commit_message("03168b97d19a2f7954e5b29a5cb18862e707ab6c")).to eq "log_message"
    end
  end
end
