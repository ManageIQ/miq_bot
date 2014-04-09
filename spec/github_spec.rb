require 'spec_helper'

describe CFMEToolsServices::Github do
  let(:service) { double("github service") }

  before do
    described_class.any_instance.stub(:service => service)
  end

  def with_service
    described_class.call(:user => "ManageIQ", :repo => "sandbox") { |git| yield git }
  end

  it_should_behave_like "ServiceMixin service"
end
