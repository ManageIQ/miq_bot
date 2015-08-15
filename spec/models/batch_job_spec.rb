require 'spec_helper'

describe BatchJob do
  it ".perform_async" do
    workers    = (1..3).collect { |i| spy("WorkerClass#{i}") }
    expires_at = 10.minutes.from_now

    described_class.perform_async(
      workers,
      %w(arg1 arg2),
      :on_complete_class => String,
      :on_complete_args  => %w(arga argb),
      :expires_at        => expires_at
    )

    job = described_class.first
    expect(job.on_complete_class).to eq(String)
    expect(job.on_complete_args).to  eq(%w(arga argb))
    expect(job.expires_at).to        eq(expires_at)

    entries = job.entries.order(:id)
    workers.zip(entries).each do |w, e|
      expect(w).to have_received(:perform_async).with(e.id, "arg1", "arg2")
    end
  end

  include_examples "state predicates", :finalizing?,
                   nil          => false,
                   "finalizing" => true

  describe "#on_complete_class / #on_complete_class=" do
    it "with a String" do
      job = described_class.new(:on_complete_class => "RSpec::Core")
      expect(job.on_complete_class).to eq(RSpec::Core)
    end

    it "with a Class" do
      job = described_class.new(:on_complete_class => RSpec::Core)
      expect(job.on_complete_class).to eq(RSpec::Core)
    end

    it "with nil" do
      job = described_class.new
      expect(job.on_complete_class).to be_nil
    end
  end

  describe "#expired?" do
    it "without an expiration" do
      job = described_class.new
      expect(job).to_not be_expired
    end

    it "with an expiration, but not yet expired" do
      job = described_class.new(:expires_at => 10.minutes.from_now)
      expect(job).to_not be_expired
    end

    it "with an expiration, and expired" do
      job = described_class.new(:expires_at => 10.minutes.ago)
      expect(job).to be_expired
    end
  end

  describe "#entries_complete?" do
    it "without entries" do
      job = described_class.new
      expect(job.entries_complete?).to be_falsey
    end

    it "with entries that are not complete" do
      job = described_class.new(:entries => [
        BatchEntry.new,
        BatchEntry.new(:state => "succeeded")
      ])
      expect(job.entries_complete?).to be_falsey
    end

    it "with entries that are complete" do
      job = described_class.new(:entries => [
        BatchEntry.new(:state => "failed"),
        BatchEntry.new(:state => "succeeded")
      ])
      expect(job.entries_complete?).to be_truthy
    end
  end

  describe "#check_complete" do
    it "when destroyed by another checker" do
      job = described_class.create!.tap(&:destroy)

      expect(job).to_not receive(:finalize!)

      job.check_complete
    end

    it "when already finalizing by another checker" do
      job = described_class.create!(:state => "finalizing")

      expect(job).to_not receive(:finalize!)

      job.check_complete
    end

    it "when entries are not complete" do
      job = described_class.create!(:entries => [
        BatchEntry.create!,
        BatchEntry.create!(:state => "succeeded")
      ])

      expect(job).to_not receive(:finalize!)

      job.check_complete
    end

    shared_examples "#finalize!" do
      before { OnCompleteWorker = Class.new }
      after  { Object.send(:remove_const, "OnCompleteWorker") }

      it "and there is an on_complete_class" do
        job.update_attributes!(
          :on_complete_class => ::OnCompleteWorker,
          :on_complete_args  => %w(arg1 arg2)
        )

        expect(OnCompleteWorker).to receive(:perform_async).with(job.id, "arg1", "arg2")

        job.check_complete

        expect(job.state).to eq("finalizing")
      end

      it "and there is no on_complete_class" do
        job.check_complete

        expect(job).to be_destroyed

        expect(described_class.any?).to be false
        expect(BatchEntry.any?).to      be false
      end
    end

    context "when entries are complete" do
      let(:job) do
        described_class.create!(:entries => [
          BatchEntry.create!(:state => "failed"),
          BatchEntry.create!(:state => "succeeded")
        ])
      end

      include_examples "#finalize!"
    end

    context "when expired" do
      let(:job) do
        described_class.create!(
          :expires_at => 10.minutes.ago,
          :entries    => [
            BatchEntry.create!,
            BatchEntry.create!(:state => "succeeded")
          ]
        )
      end

      include_examples "#finalize!"
    end
  end
end
