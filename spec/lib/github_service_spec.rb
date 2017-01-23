require 'spec_helper'

describe GithubService do
  let(:service) { double("github service") }

  before do
    allow_any_instance_of(described_class).to receive(:service).and_return(service)
  end

  def with_service
    described_class.call(:user => "ManageIQ", :repo => "sandbox") { |git| yield git }
  end

  it_should_behave_like "ThreadsafeServiceMixin service"
end
