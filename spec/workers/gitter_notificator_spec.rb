require 'spec_helper'

describe GitterNotificator do
  let(:repository) { "owner/name" }
  let(:branch) { "master" }
  let(:room) { "owner/name" }

  describe "#init" do
    let(:token) { "token" }
    let(:item_branch) { double("Branch", :repo => "R", :branch => "B", :gitter_room => "GR") }
    let(:item_travis_monitor) { double("travis_monitor", :gitter_token => token) }
    let(:build_states) { %w(state1 state2) }
    let(:msg) { "Hello!" }

    before do
      allow(Settings).to receive(:travis_monitor).and_return(item_travis_monitor)
    end

    it "calls #latest_builds, #check and #gitter_send with proper parameters" do
      allow(item_travis_monitor).to receive(:branches).and_return([item_branch])

      expect(subject).to receive(:latest_builds).with(item_branch.repo, item_branch.branch).and_return(build_states)
      expect(subject).to receive(:check).with(build_states, item_branch.repo, item_branch.branch).and_return(msg)
      expect(subject).to receive(:gitter_send).with(item_branch.gitter_room, msg, token)

      subject.send(:init)
    end
  end

  describe "#check" do
    it "sends a broken branch message" do
      expect(subject.send(:check, %w(passed failed), repository, branch)).to eq(":sos: :warning: \"#{branch}\" in \"#{repository}\" is broken :bangbang: :boom:")
    end

    it "sends a fixed branch message" do
      expect(subject.send(:check, %w(failed passed), repository, branch)).to eq(":white_check_mark: Broken branch has been fixed :green_heart:")
    end

    it "does not send a message on passing builds" do
      expect(subject).not_to receive(:gitter_send)
      subject.send(:check, %w(passed passed), repository, branch)
    end

    it "does not send a message on failing builds" do
      expect(subject).not_to receive(:gitter_send)
      subject.send(:check, %w(failed failed), repository, branch)
    end
  end

  describe "#latest_builds" do
    let(:first_expected_build) { double("Build", :state => "passed", :branch_info => branch) }
    let(:second_expected_build) { double("Build", :state => "failed", :branch_info => branch) }

    let(:valid_unexpected_build) { double("Build", :state => "state", :branch_info => branch) }
    let(:invalid_unexpected_build) { double("Build", :state => "state", :branch_info => "wrong branch") }

    let(:travis_repository) { double("Travis::Repository", :builds => [first_expected_build, invalid_unexpected_build, second_expected_build, valid_unexpected_build]) }

    it "should return the state of the last two builds" do
      allow(Travis::Repository).to receive(:find).with(repository).and_return(travis_repository)

      expect(subject.send(:latest_builds, repository, branch)).to eq([first_expected_build.state, second_expected_build.state])
    end
  end

  describe "#gitter_send" do
    let(:message) { "hello" }
    let(:gitter_token) { "token" }
    let(:gitter_rooms) { [double("Room", :name => "wrong1", :id => 1), double("Room", :name => room, :id => 2), double("Room", :name => "wrong2", :id => 3)] }
    let(:gitter_client) { double("Gitter::Client", :rooms => gitter_rooms) }

    it "sends a message" do
      allow(Gitter::Client).to receive(:new).with(gitter_token).and_return(gitter_client)

      expect(gitter_client).to receive(:send_message).with(message, 2)

      subject.send(:gitter_send, room, message, gitter_token)
    end
  end
end
