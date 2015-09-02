# ManageIQ Bot

[![Build Status](https://travis-ci.org/ManageIQ/miq_bot.svg)](https://travis-ci.org/ManageIQ/miq_bot)
[![Code Climate](https://codeclimate.com/github/ManageIQ/miq_bot/badges/gpa.svg)](https://codeclimate.com/github/ManageIQ/miq_bot)

The ManageIQ bot is the ManageIQ team's helper to automate various developer problems.

## Usage

### Automatic tasks

- Commit monitoring and reaction to commits
  - Detection of Red Hat Bugzilla URLs in commit messages
    - in pull request branches, setting the BZ to ON_DEV if not already set.
    - in regular branches, writing the commit details to the BZ ticket.
  - Detection of changes to a product's Gemfile, and setting a label.
- GitHub pull request monitoring
  - Comment on a PR when it becomes unmergeable.
  - Run [Rubocop](https://github.com/bbatsov/rubocop) and
    [haml-lint](https://github.com/brigade/haml-lint) against a PR diff and
    comment on any offenses found.
- Travis monitoring
  - Detecting stalled builds and automatically restarting them.

### Requested tasks

The bot will react to direct messages in GitHub issues, performing actions on
your behalf which would otherwise not be possible without commit rights to the
repo. Just add a comment to any issue in a monitored repo, with each request on
its own line, in the form `@miq-bot command params`.  Available commands are
below.  Any command can also be pluralized, where sensible, or have the
underscores replaced with hyphens.

- `add_label`: Add one or more labels to an issue.  Multiple labels should be
  comma-separated.  e.g. `@miq-bot add_label label1, label2, label3`
- `remove_label` (or `rm_label`): Remove one or more labels to an issue.
  Multiple labels should be comma-separated.  e.g.
  `@miq-bot remove_label label1, label2, label3`
- `assign`: Assign the issue to the specified user.  The leading `@` for the
  user is optional.  The user must be in the organization, and must have
  publicized their membership in order to be assigned.  e.g.
  `@miq-bot assign @user`
- `set_milestone`: Set the specified milestone on the issue. Do not wrap the
  milestone in quotes.  e.g. `@miq-bot set_milestone Sprint 27`

## Development

### Prerequisites

* ruby 1.9.3 with bundler
* redis ~> 2.8.10
* postgresql

### Setup

1. Fork https://github.com/ManageIQ/miq_bot

2. Clone the miq_bot repo and add the upstream remote:
   ```
   git clone git@github.com:<your github handle>/miq_bot.git
   cd miq_bot
   git remote add upstream git@github.com:ManageIQ/miq_bot.git
   git fetch —-all
   ```

3. Install any gem dependencies:
   ```
   bundle install
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

6. Create/fork a test repository (replace `miq-test/sandbox` with your test
   repository below):
   ```
   git clone -o upstream git@github.com:miq-test/sandbox.git repos/sandbox
   ```

7. Add the test repository to the database:
   ```
   bundle exec rails runner 'Repo.create_from_github!("miq-test", "sandbox", Rails.root.join("repos", "sandbox"))'
   ```

8. Create a custom Procfile for development. Any changes you make to this file
   won't be tracked.
   ```
   cp Procfile.tmpl Procfile
   ```

9. Either start redis as a daemon or have foreman start it for you by
   adding this to the `Procfile`:
   ```yaml
   redis: redis-server /path/to/redis.conf  # change this to the redis.conf provided by your package manager.
   ```

10. Configure the bot settings. First copy the template:
    ```
    cp config/settings.yml config/settings/development.local.yml
    ```

    Then set to the following values:
    ```yaml
    # config/settings.local.yml:

    # github_credentials
    #   Try to use a test account, as the account in question uses notifications
    #   and needs to read them and modify them.
    username: "some-test-account"
    password: # account token goes here

    # gemfile_checker - leave blank to disable
    pr_contacts: ["@your_username"]
    enabled_repos: ["miq-test/sandbox"]

    # issue_manager - leave blank to disable
    repo_names: ["sandbox"]

    # travis_event - leave blank to disable
    enabled_repos: ["miq-test/sandbox"]
    ```

11. You should now be able to run `foreman start` to start the services listed
    in the `Procfile`.

12. See `log/development.log` and `log/sidekiq.log` to make sure
    things are starting.

13. You should be able to open a new PR on the miq-test/sandbox
    repository with any rubocop problems, such as `MixedCaseConstant = 1`.
    Wait a few minutes and see if it comments on your PR.
