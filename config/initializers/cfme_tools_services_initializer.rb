BugzillaService.credentials = YAML.load_file(Rails.root.join('config/bugzilla_credentials.yml'))
GithubService.credentials   = YAML.load_file(Rails.root.join('config/github_credentials.yml'))
