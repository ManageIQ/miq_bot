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
