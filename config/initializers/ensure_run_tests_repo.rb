if Settings.run_tests_repo&.url
  if (url = Settings.run_tests_repo.url) && (name = Settings.run_tests_repo.name)
    path = Repo::BASE_PATH.join(name)
    MinigitService.clone(url, path) unless path.join(".git").exist?
  end
end
