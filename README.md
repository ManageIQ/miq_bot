# ManageIQ Bot

[![Build Status](https://travis-ci.org/ManageIQ/miq_bot.svg)](https://travis-ci.org/ManageIQ/miq_bot)
[![Code Climate](https://codeclimate.com/github/ManageIQ/miq_bot/badges/gpa.svg)](https://codeclimate.com/github/ManageIQ/miq_bot)

The ManageIQ bot is the ManageIQ team's helper to automate various developer
problems.  Some of the things it does are:

- Commit monitoring and reaction to commits
  - Detection of Red Hat Bugzilla URLs in the commit message, and writing the
    commit details to the Bugzilla ticket.
  - Detection of changes to a product's Gemfile, and notifying the build team
    that changes are coming.
- GitHub pull request monitoring
  - Comment on a PR when it becomes unmergeable.
  - Run [Rubocop](https://github.com/bbatsov/rubocop) against a PR diff and
    comment on any Rubocop offences found.
- GitHub issue monitoring
  - Ability to request tasks of the bot, such as setting of labels, assignment,
    and milestone, which would otherwise not be possible without commit rights
    to the repo.

## Development

### Prerequisites

* ruby 1.9.3 with bundler
* redis ~> 2.8.10
* postgresql

### Steps

1. Create/fork a sandbox repository (replace `miq-test/sandbox` with your test
   repository below):
   ```
   https://github.com/miq-test/sandbox
   ```

2. Fork https://github.com/ManageIQ/miq_bot

3. Clone the miq_bot repo and add the upstream remote:
    ```
    git clone git@github.com:<your github handle>/miq_bot.git
    cd miq_bot
    git remote add upstream git@github.com:ManageIQ/miq_bot.git
    git fetch —all
    ```

4. Add the sandbox app to the `repos` directory so it can be monitored:
   ```
   git clone -o upstream git@github.com:miq-test/sandbox.git repos/sandbox
   ```

5. Install any gem dependencies:
   ```
   bundle install
   ```

6. Open up the `config/database.yml` file in your editor. Add the
   `username` and `password` for your Postgresql database (If you set
   up the ManageIQ app locally just use the same credentials).

7. Set up the databases:
   ```
   bundle exec rake db:create:all
   bundle exec rake db:migrate
   RAILS_ENV=test bundle exec rake db:migrate
   RAILS_ENV=production bundle exec rake db:migrate
   ```

8. Add the sandbox app to the database:
   ```
   bundle exec rails runner 'CommitMonitorRepo.create_from_github!("miq-test", "sandbox", Rails.root.join("repos", "sandbox"))'
   ```

9. Either start redis as a daemon or have foreman start it for you by
   adding this to the `Procfile`:
   ```yaml
   # Procfile
   redis: redis-server /path/to/redis.conf  # change this to the redis.conf provided by your package manager.
   ```

   You may also want to disable the issue_manager (the thing that
   responds to commands such as @miq_bot add_label wip) unless you're
   testing the issue_manager:
   ```yaml
   -issue_manager:             bundle exec ruby lib/bot/miq_bot.rb
   +#issue_manager:             bundle exec ruby lib/bot/miq_bot.rb
   ```

10. Configure the bot settings. First copy the template:
    ```
    cp config/settings.yml config/settings.local.yml
    ```

    Then set to the following values:
    ```yaml
    # config/settings.local.yml:

    # github_credentials
    username: "miq-bot"
    password: # token goes here

    # gemfile_checker
    pr_contacts: ["@your_username"]
    enabled_repos: ["miq-test/sandbox"]

    # issue_manager
    repo_names: ["sandbox"]

    # travis_event
    enabled_repos: ["miq-test/sandbox"]
    ```

11. You should now be able to run `foreman start` to start the
    services listed in the `Procfile`

12. See `log/development.log` and `log/sidekiq.log` to make sure
    things are starting

13. You should be able to open new PR on the miq-test/sandbox
    repository with any rubocop problems such as `MixedCaseConstant =
    1`, wait a few minutes and see if it commented on your PR.
