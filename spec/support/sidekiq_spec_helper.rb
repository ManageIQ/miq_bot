def stub_sidekiq_logger(klass)
  allow_any_instance_of(klass).to receive(:logger).and_return(double("logger").as_null_object)
end
