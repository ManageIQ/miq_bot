def stub_sidekiq_logger(klass = nil)
  klass ||= described_class
  allow_any_instance_of(klass).to receive(:logger).and_return(double("logger").as_null_object)
end
