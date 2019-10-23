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

        valid, invalid = extract_repo_names(value)

        if invalid.any?
          message = "@#{issuer} Ignoring the following repo name#{"s" if invalid.length > 1} because they are invalid: "
          message << invalid.join(", ")
          issue.add_comment(message)
          return
        end

        if valid.any?
          issue.add_comment("@#{issuer} Added cross-repo tests against the following branch(es): '#{value}' ")
          create_pr(normalize_repo_name(value), issuer)
        end
      end

      #
      def extract_repo_names(value)
        # needs to also handle # and @ 
        repo_names = value.split(",").map { |repo| repo.strip }
        validate_repos(repo_names)
      end

      def validate_repos(repo_names)
        repo_names.partition { |r| GithubService.repository?(normalize_repo_name(r)) }
      end
      #

      def normalize_repo_name(repo_name)
        repo_name.include?("/") ? repo_name : "ManageIQ/#{repo_name}"
      end

      def create_pr(repo_name, issuer)
        pr = issue.as_pull_request

        git = Repo.new(:name => Settings.run_tests_repo.name).git_service
        branch = git.create_branch("#{repo_name.tr("/", "-")}-#{issue.number}-#{SecureRandom.uuid}", "master")

        content = YAML.parse(branch.content_at(".travis.yml"))
        content["env"]["matrix"] = [
          "TEST_REPO=#{repo_name}",
          "MANAGEIQ_CORE_REF=#{pr.head.sha}"
        ]
        content["env"]["global"] = [
          "CORE_REPO=#{}",
          "GEM_REPOS=#{}"
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
