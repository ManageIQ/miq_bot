require 'spec_helper'

describe BatchEntry do
  include_examples "state predicates", :succeeded?,
                   nil         => false,
                   "started"   => false,
                   "failed"    => false,
                   "skipped"   => false,
                   "succeeded" => true

  include_examples "state predicates", :failed?,
                   nil         => false,
                   "started"   => false,
                   "failed"    => true,
                   "skipped"   => false,
                   "succeeded" => false

  include_examples "state predicates", :skipped?,
                   nil         => false,
                   "started"   => false,
                   "failed"    => false,
                   "skipped"   => true,
                   "succeeded" => false

  include_examples "state predicates", :complete?,
                   nil         => false,
                   "started"   => false,
                   "failed"    => true,
                   "skipped"   => true,
                   "succeeded" => true

  describe "#check_job_complete" do
    let(:job)   { BatchJob.create! }
    let(:entry) { described_class.create!(:job => job) }

    context "when complete" do
      before do
        entry.update_attributes(:state => "succeeded")
      end

      it "with job still available" do
        expect(job).to receive(:check_complete)

        entry.check_job_complete
      end

      it "when job destroyed externally" do
        entry.reload # To remove job caching
        job.destroy

        expect { entry.check_job_complete }.to_not raise_error
      end
    end

    it "when not complete" do
      expect(job).to_not receive(:check_complete)

      entry.check_job_complete
    end
  end
end
