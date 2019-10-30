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
        repo_names = value.split(",").map(&:strip)
        validate_repos(repo_names)
      end

      def validate_repos(repo_names)
        repo_names.partition { |r| GithubService.repository?(normalize_repo_name(r)) }
      end

      def normalize_repo_name(repo_name)
        repo_name.include?("/") ? repo_name : "ManageIQ/#{repo_name}"
      end

      def create_repo(name = Settings.run_tests_repo.name)
        Repo.new(:name => name).git_service
      end

      def create_pr(repo_name, issuer)
        pr = issue.as_pull_request

        branch = create_repo.create_branch("#{repo_name.tr("/", "-")}-#{issue.number}-#{SecureRandom.uuid}", "master")
        # check to see if yml is already there and do things and stuff and things and more things
        content = YAML.safe_load(branch.content_at(".travis.yml"))
        content["env"] = {} unless content["env"]
        content["env"]["matrix"] = [
          "TEST_REPO=#{repo_name}",
          "MANAGEIQ_CORE_REF=#{pr.head.sha}"
        ]
        content["env"]["global"] = [
          "CORE_REPO=#{}",
          "GEM_REPOS=#{}"
        ]
        content = content.to_yaml
        file = open('.travis.yml', 'w')
        file << content
        file.close

        repo = branch.send(:rugged_repo)
        index = repo.index
        index.add('.travis.yml')
        index.write

        oid = repo.write(content, :blob)
        index = repo.index
        index.read_tree(repo.head.target.tree)
        index.add(:path => ".travis.yml", :oid => oid, :mode => 0100644)
        index.write

        options = {}
        options[:tree] = index.write_tree(repo)

        options[:author] = { :email => "testuser@github.com", :name => 'Test Author', :time => Time.now }
        options[:committer] = { :email => "testuser@github.com", :name => 'Test Author', :time => Time.now }
        options[:message] ||= "Updating .travis.yml"
        options[:parents] = repo.empty? ? [] : [repo.head.target].compact
        options[:update_ref] = 'HEAD'

        Rugged::Commit.create(repo, options)
      end
    end
  end
end
