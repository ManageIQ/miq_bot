require 'spec_helper'

describe BatchEntry do
  include_examples "state predicates", :succeeded?,
                   nil         => false,
                   "started"   => false,
                   "failed"    => false,
                   "succeeded" => true

  include_examples "state predicates", :failed?,
                   nil         => false,
                   "started"   => false,
                   "failed"    => true,
                   "succeeded" => false

  include_examples "state predicates", :complete?,
                   nil         => false,
                   "started"   => false,
                   "failed"    => true,
                   "succeeded" => true

  describe "#check_job_complete" do
    let(:entry) { described_class.create!(:job => BatchJob.create!) }
    let(:job)   { entry.job }

    it "when complete" do
      entry.update_attributes(:state => "succeeded")

      expect(job).to receive(:check_complete)

      entry.check_job_complete
    end

    it "when not complete" do
      expect(job).to_not receive(:check_complete)

      entry.check_job_complete
    end
  end
end
