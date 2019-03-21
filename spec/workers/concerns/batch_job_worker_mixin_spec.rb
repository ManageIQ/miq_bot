require 'rails_helper'

describe BatchJobWorkerMixin do
  let(:includer_class) do
    Class.new do
      include BatchJobWorkerMixin

      def self.batch_workers
        @batch_workers ||= [Class.new, Class.new]
      end

      def logger
        @logger ||= RSpec::Mocks::Double.new("logger")
      end
    end
  end

  subject   { includer_class.new }
  let(:job) { BatchJob.create! }

  it ".perform_batch_async" do
    expect(BatchJob).to receive(:perform_async) do |workers, worker_args, job_attributes|
      expect(workers).to     eq(includer_class.batch_workers)
      expect(worker_args).to eq(%w(arg1 arg2))

      expect(job_attributes[:on_complete_class]).to eq(includer_class)
      expect(job_attributes[:on_complete_args]).to  eq(%w(arg1 arg2))
      expect(job_attributes[:expires_at]).to        be_kind_of(Time)
    end

    includer_class.perform_batch_async("arg1", "arg2")
  end

  describe "#find_batch_job" do
    it "with an existing job" do
      expect(subject.find_batch_job(job.id)).to be true
    end

    it "with a missing job" do
      expect(subject.logger).to receive(:warn) do |message|
        expect(message).to match(/no longer exists/)
      end
      expect(subject.find_batch_job(-1)).to be false
    end
  end

  it "#complete_batch_job" do
    subject.find_batch_job(job.id)

    subject.complete_batch_job

    expect { job.reload }.to raise_error(ActiveRecord::RecordNotFound)
  end
end
