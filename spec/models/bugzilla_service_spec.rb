require 'spec_helper'

describe BugzillaService do
  let(:service) { double("bugzilla service") }

  before do
    described_class.any_instance.stub(:service => service)
  end

  def with_service
    described_class.call { |bz| yield bz }
  end

  it_should_behave_like "ServiceMixin service"

  context "native bz methods" do
    it "#query" do
      expect(service).to receive(:query).with(:bug_id => 123456)
      with_service { |bz| bz.query(:bug_id => 123456) }
    end

    it "#modify" do
      expect(service).to receive(:modify).with(123456, "Fixed")
      with_service { |bz| bz.modify(123456, "Fixed") }
    end
  end
end
