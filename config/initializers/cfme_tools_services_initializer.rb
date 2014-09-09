MiqToolsServices::Bugzilla.credentials = YAML.load_file(Rails.root.join('config/bugzilla_credentials.yml'))
MiqToolsServices::Github.credentials   = YAML.load_file(Rails.root.join('config/github_credentials.yml'))
