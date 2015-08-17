def stub_job_completion
  allow_any_instance_of(described_class).to receive(:check_job_complete)
end
