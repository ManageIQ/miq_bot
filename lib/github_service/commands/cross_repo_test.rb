module GithubService
  module Commands
    # = GithubService::Commands::CrossRepoTest
    #
    # Triggers a build given the configured test repo:
    #
    #   Settings.cross_repo_tests_repo.*
    #
    # Which doing so will:
    #
    #    - validate the command
    #    - create a branch
    #    - create a commit with the travis.yml changes
    #    - push said branch to the origin
    #    - create a pull request for that branch
    #
    # More info can be found here on how the whole process works:
    #
    #   https://github.com/ManageIQ/manageiq-cross_repo-tests
    #
    # == Command structure
    #
    # @miq-bot cross-repo-test [<repos-to-test>] [including <extra-repos>]
    #
    # where:
    #
    #   - a `repo` is of the form [org/]repo[@ref|#pr]
    #   - `repos-to-test` is a list of repos to have tested
    #   - `extra-repos` is a list of repos (gems) to override in the bundle
    #
    # each "lists of repos" should be comma delimited.
    #
    # == Example
    #
    # In ManageIQ/manageiq PR #1234
    #
    #   @miq-bot cross-repo-test manageiq-api,manageiq-ui-classic#5678 \
    #     including Fryguy/more_core_extensions@feature,Fryguy/linux_admin@feature
    #
    # will create a commit with the .travis.yml changes:
    #
    #   @@ -14,6 +14,6 @@ matrix:
    #      fast_finish: true
    #    env:
    #      global:
    #   -  - REPOS=
    #   +  - REPOS=Fryguy/more_core_extensions@feature,Fryguy/linux_admin@feature,ManageIQ/manageiq#1234,manageiq-ui-classic#5678
    #      matrix:
    #   -  - TEST_REPO=
    #   +  - TEST_REPO=ManageIQ/manageiq#1234
    #   +  - TEST_REPO=ManageIQ/manageiq-api
    #   +  - TEST_REPO=ManageIQ/manageiq-ui-classic#5678
    class CrossRepoTest < Base
      # Reference to the branch we are creating off of origin/master
      attr_reader :branch_ref

      # The user calling the command
      attr_reader :issuer

      # The (extra) repo(s) being targeted to be included in the test run
      attr_reader :repos

      # The repo(s) that will have the test suite run
      attr_reader :test_repos

      # The *-cross_repo-tests rugged instance
      attr_reader :rugged_repo

      # The arguments for the `cross-repo-test` command being called
      attr_reader :value

      restrict_to :organization

      # Cache the repo groups yaml file from https://github.com/ManageIQ/manageiq-release
      cache_with_timeout(:repo_groups_hash, 60.minutes) { fetch_manageiq_release_repo_groups }

      def self.test_repo_url
        Settings.cross_repo_tests.url
      end

      def self.test_repo_name
        Settings.cross_repo_tests.name
      end

      def self.test_repo_clone_dir
        @test_repo_clone_dir ||= begin
                                   url_parts = test_repo_url.split("/")[-2, 2]
                                   repo_org  = url_parts.first
                                   repo_dir  = test_repo_name
                                   ::Repo::BASE_PATH.join(repo_org, repo_dir).to_s
                                 end
      end

      def self.bot_name
        Settings.github_credentials.username
      end

      def self.bot_email
        Settings.github_credentials.email || "no_bot_email@example.com"
      end

      # The new branch name for this particular run of the command (uniq)
      def branch_name
        @branch_name ||= begin
                           uuid     = SecureRandom.uuid
                           bot_name = self.class.bot_name
                           issue_id = "#{issue.repo_name}-#{issue.number}"

                           "#{uuid}-#{bot_name}-run-tests-#{issue_id}"
                         end
      end

      def run_tests
        ensure_test_repo_clone
        create_cross_repo_test_branch
        update_travis_yaml_content
        commit_travis_yaml_changes
        push_commit_to_remote
        create_cross_repo_test_pull_request
      end

      private

      def _execute(issuer:, value:)
        @issuer = issuer
        parse_value(value)
        return unless valid?

        run_tests
      end

      def parse_value(value)
        @value = value

        @test_repos, @repos = value.split(/\s+including\s+/)
                                   .map { |repo_list| repo_list.split(",").map(&:strip) }
        @repos ||= []

        # Ignore bare repos in include list
        @repos.select! { |repo| branch_or_pr?(repo) }

        # Expand repo groups (e.g. /providers) in the test repos
        @test_repos = @test_repos.flat_map { |repo| repo_group?(repo) ? expand_repo_group(repo) : repo }.compact

        # Add the PR for this comment to the test repos
        @test_repos << "#{issue.repo_name}##{issue.number}"

        # Normalize the repo names
        @test_repos = normalize_repo_list(@test_repos)
        @repos      = normalize_repo_list(@repos)

        # Ensure all test repos that are PRs/branches are included with other test repos
        @repos += @test_repos.select { |repo| branch_or_pr?(repo) }

        # Ensure that any PRs/branches in the included list override bare test repos
        test_repos_bare = @test_repos.map { |repo| bare_repo_name(repo) }
        @test_repos += @repos.select { |repo| test_repos_bare.include?(bare_repo_name(repo)) }

        # Dedup the repo lists
        @test_repos = dedup_repo_list(@test_repos)
        @repos      = dedup_repo_list(@repos)
      end

      def repo_group?(repo)
        repo.start_with?("/")
      end

      def expand_repo_group(repo_group)
        # repo_group is of the format "/providers"
        key = repo_group.sub("/", "")
        self.class.repo_groups_hash[key]
      end

      def normalize_repo_list(repo_list)
        repo_list.map { |repo| normalize_repo_name(repo) }
      end

      def normalize_repo_name(repo)
        repo = repo.strip
        repo.include?("/") ? repo : "#{issue.organization_name}/#{repo}"
      end

      # Deduplicates entries sharing the same bare repo name, prioritizing
      #   PRs/branches over bare repo names.
      def dedup_repo_list(repo_list)
        repo_list
          .sort # Unadorned repo name will always sort before adorned repo names
          .uniq
          .slice_when { |a, b| bare_repo_name(a) != bare_repo_name(b) }
          .map do |repos|
            repos.shift if repos.size > 1 && bare_repo?(repos.first)
            repos.size == 1 ? repos.first : repos
          end
      end

      def bare_repo_name(repo)
        repo.split(/[@#]/, 2).first
      end

      def branch_or_pr?(repo)
        repo.match?(/[@#]/)
      end

      def bare_repo?(repo)
        !branch_or_pr?(repo)
      end

      def valid?
        validate_pull_request &&
          validate_repo_names &&
          validate_conflict_repos
      end

      def validate_pull_request
        return true if issue.pull_request?

        issue.add_comment("@#{issuer} 'cross-repo-test(s)' command is only valid on pull requests, ignoring...")
        false
      end

      def validate_repo_names
        invalid_repo_names = (@test_repos + @repos).select { |r| r.include?(" ") }.sort.uniq
        return true if invalid_repo_names.empty?

        message = "@#{issuer} 'cross-repo-test(s)' was given invalid repo names and cannot continue\n\n"
        invalid_repo_names.each do |repo|
          message << "* `#{repo}`\n"
        end

        issue.add_comment(message)
        false
      end

      def validate_conflict_repos
        conflicts = (@test_repos + @repos).select { |r| r.kind_of?(Array) }.sort.uniq
        return true if conflicts.empty?

        message = "@#{issuer} 'cross-repo-test(s)' was given conflicting repo names and cannot continue\n\n"
        conflicts.each do |repos|
          pretty_repos = repos.map { |r| "`#{r}`" }.join(", ")
          message << "* #{pretty_repos} conflict\n"
        end

        issue.add_comment(message)
        false
      end

      ##### run_tests steps #####

      # Clone repo (if needed) and initialize @rugged_repo
      def ensure_test_repo_clone
        repo_path = self.class.test_repo_clone_dir
        if Dir.exist?(repo_path)
          @rugged_repo = Rugged::Repository.new(repo_path)
        else
          url = self.class.test_repo_url
          @rugged_repo = Rugged::Repository.clone_at(url, repo_path, :bare => true)
        end
        git_fetch
      end

      def create_cross_repo_test_branch
        @branch_ref = rugged_repo.create_branch(branch_name, "origin/master")
      end

      # A lot of this is borrowed from some excellent work by Madhu:
      #
      #   https://github.com/ManageIQ/manageiq/blob/06de0607/lib/git_worktree.rb#L102-L110
      #
      def update_travis_yaml_content
        raw_yaml = rugged_repo.blob_at(branch_ref.target.oid, ".travis.yml").content
        content  = YAML.safe_load(raw_yaml)

        content["env"] = {} unless content["env"]
        content["env"]["global"] = ["REPOS=#{repos.join(',')}"]
        content["env"]["matrix"] = test_repos.map { |repo| "TEST_REPO=#{repo}" }

        entry = {}
        entry[:path]  = ".travis.yml"
        entry[:oid]   = @rugged_repo.write(content.to_yaml, :blob)
        entry[:mode]  = 0o100644
        entry[:mtime] = Time.now.utc

        rugged_index.add(entry)
        # rugged_index.write (don't do this...)
      end

      def commit_travis_yaml_changes
        bot       = self.class.bot_name
        author    = {:name => issuer, :email => user_email(issuer),   :time => Time.now.utc}
        committer = {:name => bot,    :email => self.class.bot_email, :time => Time.now.utc}

        Rugged::Commit.create(
          rugged_repo,
          :author     => author,
          :committer  => committer,
          :parents    => [branch_ref.target],
          :tree       => rugged_index.write_tree(rugged_repo),
          :update_ref => "refs/heads/#{branch_name}",
          :message    => <<~COMMIT_MSG
            Running tests for #{issuer}

            From Pull Request:  #{issue.fq_repo_name}##{issue.number}
          COMMIT_MSG
        )
      end

      def push_commit_to_remote
        push_options = {}

        if Settings.github_credentials.username && Settings.github_credentials.password
          rugged_creds = Rugged::Credentials::UserPassword.new(
            :username => Settings.github_credentials.username,
            :password => Settings.github_credentials.password
          )
          push_options[:credentials] = rugged_creds
        end

        remote = @rugged_repo.remotes['origin']
        remote.push(["refs/heads/#{branch_name}"], push_options)
      end

      def create_cross_repo_test_pull_request
        fq_repo_name = "#{issue.organization_name}/#{File.basename(self.class.test_repo_url, '.*')}"
        pr_desc      = <<~PULL_REQUEST_MSG
          From Pull Request:  #{issue.fq_repo_name}##{issue.number}
          For User:           @#{issuer}
        PULL_REQUEST_MSG

        GithubService.create_pull_request(fq_repo_name,
                                          "master", branch_name,
                                          "[BOT] Cross repo test for #{issue.fq_repo_name}##{issue.number}", pr_desc)
      end

      def self.fetch_manageiq_release_repo_groups
        require 'net/http'
        require 'uri'

        uri = URI.parse("https://raw.githubusercontent.com/ManageIQ/manageiq-release/master/config/repos.sets.yml")
        response = Net::HTTP.get_response(uri)
        response.value

        YAML.safe_load(response.body, :aliases => true).transform_values(&:keys)
      rescue
        # If the get_response call fails return an empty hash
        {}
      end
      private_class_method :fetch_manageiq_release_repo_groups

      ##### Duplicate Git stuffs #####

      # Code that probably should be refactored to be shared elsewhere, but for
      # now just shoving it here to get a working prototype together.

      # Mostly a dupulicate from Repo.git_fetch (app/models/repo.rb)
      #
      # Don't need the credentials stuff since we are assuming https for this repo
      def git_fetch
        rugged_repo.remotes.each { |remote| rugged_repo.fetch(remote.name) }
      end

      def user_email(username)
        GithubService.user(username).try(:email) || "no-name@example.com"
      end

      # Create a new Rugged::Index based off of "refs/remote/origin/master"
      #
      # Based off of GitWorktree in ManageIQ/manageiq
      #
      #   https://github.com/ManageIQ/manageiq/blob/06de0607/lib/git_worktree.rb#L395-L404
      #
      def rugged_index
        @rugged_index ||= Rugged::Index.new.tap do |index|
          index.read_tree(branch_ref.target.tree)
        end
      end
    end
  end
end
