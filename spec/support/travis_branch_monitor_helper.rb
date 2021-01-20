require 'yaml'

module IncludedReposConfigMethods
  def included_repos_keys_only
    YAML.safe_load <<~YAML
      ---
      travis_branch_monitor:
        included_repos:
          ManageIQ/manageiq:
          ManageIQ/miq_bot:
    YAML
  end

  def included_repos_keys_and_values
    YAML.safe_load <<~YAML
      travis_branch_monitor:
        included_repos:
          ManageIQ/manageiq-ui-classic: ManageIQ/ui
          ManageIQ/manageiq-gems-pending: ManageIQ/core
    YAML
  end

  def included_repos_mixed_keys_with_some_values
    YAML.safe_load <<~YAML
      travis_branch_monitor:
        included_repos:
          ManageIQ/manageiq-ui-classic: ManageIQ/ui
          ManageIQ/manageiq-gems-pending: ManageIQ/core
          ManageIQ/manageiq:
          ManageIQ/miq_bot:
    YAML
  end
end
