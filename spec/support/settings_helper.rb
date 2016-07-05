def stub_settings(hash)
  settings = Config::Options.new.merge!(hash)
  stub_const("Settings", settings)
end
