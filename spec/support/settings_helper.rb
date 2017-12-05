def stub_settings(hash)
  settings = Config::Options.new
  settings.merge!(Settings.to_hash)
  settings.merge!(hash)
  stub_const("Settings", settings)
end

# Need a special stub for nil settings until https://github.com/danielsdeleo/deep_merge/pull/33
# is released with the config gem
def stub_nil_settings(hash)
  settings = Config::Options.new
  settings.merge!(hash)
  stub_const("Settings", settings)
end
