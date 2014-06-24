require 'spec_helper'

describe CFMEToolsServices::Bugzilla do
  let(:service) { double("bugzilla service") }

  before do
    described_class.any_instance.stub(:service => service)
  end

  def with_service
    described_class.call { |bz| yield bz }
  end

  it_should_behave_like "ServiceMixin service"

  context ".ids_in_git_commit_message" do
    it "with no bugs" do
      message = <<-EOF
This is a commit message
      EOF

      expect(described_class.ids_in_git_commit_message(message)).to eq([])
    end

    it "with one bug" do
      message = <<-EOF
This is a commit message

https://bugzilla.redhat.com/show_bug.cgi?id=123456
      EOF

      expect(described_class.ids_in_git_commit_message(message)).to eq([123456])
    end

    it "with multiple bugs" do
      message = <<-EOF
This is a commit message

https://bugzilla.redhat.com/show_bug.cgi?id=123456
https://bugzilla.redhat.com/show_bug.cgi?id=345678
      EOF

      expect(described_class.ids_in_git_commit_message(message)).to eq([123456, 345678])
    end

    it "with oddly formed URL" do
      message = <<-EOF
This is a commit message

https://bugzilla.redhat.com//show_bug.cgi?id=123456
      EOF

      expect(described_class.ids_in_git_commit_message(message)).to eq([123456])
    end
  end

  context "native bz methods" do
    it "#query" do
      expect(service).to receive(:search).with(:id => 123456)
      with_service { |bz| bz.search(:id => 123456) }
    end

    it "#modify" do
      expect(service).to receive(:add_comment).with(123456, "Fixed")
      with_service { |bz| bz.add_comment(123456, "Fixed") }
    end
  end
end
