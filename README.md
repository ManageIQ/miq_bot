# ManageIQ Bot

[![CI](https://github.com/ManageIQ/miq_bot/actions/workflows/ci.yaml/badge.svg)](https://github.com/ManageIQ/miq_bot/actions/workflows/ci.yaml)
[![Code Climate](https://codeclimate.com/github/ManageIQ/miq_bot.svg)](https://codeclimate.com/github/ManageIQ/miq_bot)
[![Test Coverage](https://codeclimate.com/github/ManageIQ/miq_bot/badges/coverage.svg)](https://codeclimate.com/github/ManageIQ/miq_bot/coverage)

The ManageIQ bot is the ManageIQ team's helper to automate various developer problems.

## Usage

### Automatic tasks

- Commit monitoring and reaction to commits
  - Detection of changes to a product's Gemfile, and setting a label.
- GitHub pull request monitoring
  - Label and comment on a PR when it becomes unmergeable.
  - Run [Rubocop](https://github.com/bbatsov/rubocop),
    [haml-lint](https://github.com/brigade/haml-lint) and
    [yamllint](https://yamllint.readthedocs.io/en/stable/index.html)
    against a PR diff and comment on any offenses found.

### Requested tasks

The bot will react to direct messages in GitHub issues, performing actions on
your behalf which would otherwise not be possible without commit rights to the
repo. Just add a comment to any issue in a monitored repo, with each request on
its own line, in the form `@miq-bot command params`.  Available commands are
below.  Any command can also be pluralized, where sensible, or have the
underscores replaced with hyphens.

- **`add_label label1[, label2]`**
  Add one or more labels to an issue.  Multiple labels should be
  comma-separated.

  Example: `@miq-bot add_labels label1, label2`

- **`remove_label label1[, label2]`**
  Remove one or more labels to an issue. Multiple labels should be comma-separated.

  Example: `@miq-bot remove_label wontfix`

- **`assign [@]user`**
  Assign the issue to the specified user.  The leading `@` for the
  user is optional.  The user must be in the Assignees list.

  Example: `@miq-bot assign @user`

- **`unassign [@]user`**
  Unassign the issue or pull request to the specified user(s). The leading `@` for the
  user is optional. The user(s) must be assigned to the issue or pull request and they
  must be comma separated.

  Example: `@miq-bot unassign @user1[, @user2]`

- **`add_reviewer [@]user`**
  Request for pull request review the specified user. The leading `@` for the
  user is optional. The users must be separated by a comma and they must be
  in the Assignees list.

  Example: `@miq-bot add_reviewer @user1[, @user2]`

- **`remove_reviewer [@]user`**
  Remove a request for pull request review from the specified user. The leading `@` for the
  user is optional. The user must be in the Assignees list.

  Example: `@miq-bot remove_reviewer @user`

- **`set_milestone milestone_name`**
  Set the specified milestone on the issue. Do not wrap the
  milestone in quotes.

  Example: `@miq-bot set_milestone Sprint 27`

- **`move_issue [organization_name/]repo_name`**
  Moves the issue to the specified repo. The bot will open a new issue with
  your original title and description and close the current one. Useful for
  reorganizing issues opened on the core ManageIQ/manageiq repo to a more
  appropriate project (a provider or other ManageIQ plugin).

  * This command is restricted to members of the organization containing the issue.
  * The repository being moved to must be under the same organization as the issue being moved.
  * You cannot move a pull request.

  Example: `@miq-bot move_issue manageiq-providers-amazon`

- **`close_issue`**
  Closes the issue.

  * This command is restricted to members of the organization containing the issue.
  * Restricted use on pull requests. Only the pull request author or a committer can close
    pull requests (who have access to close them directly anyway). This is intended.

  Example: `@miq-bot close_issue`

- **`cross_repo_test test_repos* [including include_repos*]`**
  Runs cross repo tests that include the current PR code base. A pull request will
  be created in the [manageiq-cross_repo-tests repo](https://github.com/ManageIQ/manageiq-cross_repo-tests)
  where each of the `test_repos` will be a separate entry in the test matrix. Those
  tests will run in the context of all repos declared in `test_repos` +
  `include_repos` + the PR itself.

  * This command is restricted to members of the organization containing the issue.
  * Restricted use on pull requests.  This doesn't make sense to use on issues
    since there is no code to run.

  Example: `@miq-bot cross_repo_tests ManageIQ/manageiq#1234 including more_core_extensions@1234abcd`

  Also accepts repository groups, e.g. `/providers`, `/core`, `/all`

  Example: `@miq-bot cross_repo_tests ManageIQ/manageiq#1234, /providers including more_core_extensions@1234abcd

## Development

### Prerequisites

* Ruby 2.2 with bundler
* Redis ~> 2.8.10
* Postgresql
* pip

### Setup

1. Fork https://github.com/ManageIQ/miq_bot

2. Clone the miq_bot repo and add the upstream remote:
   ```
   git clone git@github.com:<your github handle>/miq_bot.git
   cd miq_bot
   git remote add upstream git@github.com:ManageIQ/miq_bot.git
   git fetch —-all
   ```

3. Install any dependencies:
   ```
   bundle install
   sudo pip install yamllint
   ```

4. Create the `database.yml` file.
   ```
   cp config/database.tmpl.yml config/database.yml
   ```
   Edit the `database.yml` file, and change `username` and `password` for your
   PostgreSQL database.

5. Set up the databases:
   ```
   bundle exec rake db:setup
   ```

6. Create/fork a test repository and add it to the database (replace `miq-test/sandbox` with your test
   repository below).  Note that the bot account you are using must have SSH keys defined correctly
   if you plan to use an SSH based URL, otherwise you should use an HTTPS based URL.
   ```
   bundle exec rails runner 'Repo.create_from_github!("miq-test/sandbox", "https://github.com/miq-test/sandbox.git")'
   ```

7. Create a custom Procfile for development. Any changes you make to this file
   won't be tracked.
   ```
   cp Procfile.tmpl Procfile
   ```

8. Either start redis as a daemon or have foreman start it for you by
   adding this to the `Procfile`:
   ```yaml
   redis: redis-server /path/to/redis.conf  # change this to the redis.conf provided by your package manager.
   ```

9. Configure the bot settings. First copy the template:
    ```
    cp config/settings.yml config/settings/development.local.yml
    ```

    Then set to the following values:
    ```yaml
    # config/development.local.yml:

    #   Try to use a test account, as the account in question uses notifications
    #   and needs to read them and modify them.
    github_credentials:
      username: "some-test-account"
      password: # account token goes here

    # Optional; See the section on enabling/disabling workers
    github_notification_monitor:
      included_repos: ["miq-test/sandbox"]
    ```

10. You should now be able to run `foreman start` to start the services listed
    in the `Procfile`.

11. See `log/development.log` and `log/sidekiq.log` to make sure
    things are starting.

12. You should be able to open a new PR on the miq-test/sandbox
    repository with any rubocop problems, such as `MixedCaseConstant = 1`.
    Wait a few minutes and see if it comments on your PR.

### Enabling and Disabling workers

By default, most workers are enabled for all repos (except for the MergeTargetTitler
which is disabled for all repos), however if you would like to change which workers
are enabled or disabled, the following configuration settings can be changed:

```yaml
worker_a:  # Will run in all repos

worker_b:  # Will only run in the specified repos
  included_repos:
  - "org1/repo1"
  - "org2/repo2"

worker_c:  # Will run in all repos except the specified repos
  excluded_repos:
  - "org1/repo1"
  - "org2/repo2"

worker_d:  # Will raise an exception, since you should not specify both
  included_repos:
  - "org1/repo1"
  excluded_repos:
  - "org2/repo2"

worker_e:  # Effectively disables the worker
  included_repos: []
```
