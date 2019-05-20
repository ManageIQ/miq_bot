describe BatchJobMonitor do
  it "#perform_check" do
    BatchJob.create!

    expect_any_instance_of(BatchJob).to receive(:check_complete)

    described_class.new.perform_check
  end
end
