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
    #   +  - TEST_REPO=ManageIQ/manageiq-api
    #   +  - TEST_REPO=ManageIQ/manageiq-ui-classic#5678
    #
    # TODO:  Handle the "self" case, where `manageiq` is also a TEST_REPO
    #
    # (maybe include a "self" helper as well?)
    #
    class CrossRepoTest < Base
      # The user calling the command
      attr_reader :issuer

      # The (extra) repo(s) being targeted to be included in the test run
      attr_reader :repos

      # The repo(s) that will have the test suite run
      attr_reader :test_repos

      # The arguments for the `cross-repo-test` command being called
      attr_reader :value

      restrict_to :organization

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
                                   .map { |repo_list| repo_list.split(",") }

        # Add the identifier for the PR for this comment to @repos here
        @repos ||= []
        @repos  << "#{issue.repo_name}##{issue.number}"

        @test_repos.map! { |repo_name| normalize_repo_name(repo_name.strip) }
        @repos.map!      { |repo_name| normalize_repo_name(repo_name.strip) }

        [@repos, @test_repos].each(&:uniq!)
      end

      def normalize_repo_name(repo)
        repo.include?("/") ? repo : "#{issue.organization_name}/#{repo}"
      end

      def valid?
        unless issue.pull_request?
          issue.add_comment("@#{issuer} 'cross-repo-test(s)' command is only valid on pull requests, ignoring...")
          return false
        end

        true
      end

      def run_tests
        create_cross_repo_test_branch
        commit_yaml_changes
        push_push_commit_to_remote
        create_cross_repo_test_pull_request
      end

      def create_cross_repo_test_branch
        # TODO
      end

      def commit_yaml_changes
        # TODO
      end

      def push_push_commit_to_remote
        # TODO
      end

      def create_cross_repo_test_pull_request
        # TODO
      end
    end
  end
end
