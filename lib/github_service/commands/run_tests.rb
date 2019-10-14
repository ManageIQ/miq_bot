module GithubService
  module Commands
    class RunTests < Base
      restrict_to :organization

      private

      def _execute(issuer:, command:, value:)
        unless issue.pull_request?
          issue.add_comment("@#{issuer} '#{command}' command is only valid on pull requests, ignoring...")
          return
        end

        unless valid_value?(value)
          issue.add_comment("@#{issuer} '#{value}' is an invalid repo, ignoring...")
          return
        end

        create_pr(normalize_repo_name(value), issuer)
      end

      def valid_value?(repo_name)
        GithubService.repository?(normalize_repo_name(repo_name))
      end

      def normalize_repo_name(repo_name)
        repo_name.includes?("/") ? repo_name : "ManageIQ/#{repo_name}"
      end

      def create_pr(repo_name, issuer)
        pr = issue.as_pull_request

        git = Repo.new(:name => Settings.run_tests_repo.name).git_service
        branch = git.create_branch("#{repo_name.tr("/", "-")}-#{issue.number}-#{SecureRandom.uuid}", "master")

        content = YAML.parse(branch.content_at(".travis.yml"))
        content["env"] = [
          "TEST_REPO=#{repo_name}",
          "MANAGEIQ_CORE_REF=#{pr.head.sha}"
        ]
        content = content.to_yaml

        commit = branch.create_commit(".travis.yml" => content)

        # oid = repo.write("This is a blob.", :blob)
        # index = repo.index
        # index.read_tree(repo.head.target.tree)
        # index.add(:path => "README.md", :oid => oid, :mode => 0100644)

        # options = {}
        # options[:tree] = index.write_tree(repo)

        # options[:author] = { :email => "testuser@github.com", :name => 'Test Author', :time => Time.now }
        # options[:committer] = { :email => "testuser@github.com", :name => 'Test Author', :time => Time.now }
        # options[:message] ||= "Making a commit via Rugged!"
        # options[:parents] = repo.empty? ? [] : [ repo.head.target ].compact
        # options[:update_ref] = 'HEAD'

        # Rugged::Commit.create(repo, options)
      end
    end
  end
end
