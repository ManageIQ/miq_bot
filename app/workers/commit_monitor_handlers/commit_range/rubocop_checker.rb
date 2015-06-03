class CommitMonitorHandlers::CommitRange::RubocopChecker
  include Sidekiq::Worker
  sidekiq_options :queue => :miq_bot

  def self.handled_branch_modes
    [:pr]
  end

  attr_reader :branch, :pr, :commits, :results, :github

  def perform(branch_id, new_commits)
    @branch  = CommitMonitorBranch.where(:id => branch_id).first

    if @branch.nil?
      logger.info("Branch #{branch_id} no longer exists.  Skipping.")
      return
    end
    unless @branch.pull_request?
      logger.info("Branch #{@branch.name} is not a pull request.  Skipping.")
      return
    end

    @pr      = @branch.pr_number
    @commits = @branch.commits_list
    process_branch
  end

  private

  def process_branch
    diff_details = filter_ruby_files(diff_details_for_branch)
    files        = diff_details.keys

    if files.length == 0
      @results = {"files" => []}
    else

      @results = linter_results('rubocop', :files => files, :format => 'json')
      haml = linter_results('haml-lint', :files => files, :reporter => 'json')

      # Merge RuboCop and haml-lint results
      %w(offense_count target_file_count inspected_file_count).each do |m|
        @results['summary'][m] += haml['summary'][m]
      end
      @results['files'] += haml['files']

      @results = RubocopResultsFilter.new(@results, diff_details).filtered
    end

    write_to_github
  end

  def diff_details_for_branch
    MiqToolsServices::MiniGit.call(branch.repo.path) do |git|
      git.diff_details(commits.first, commits.last)
    end
  end

  def filter_ruby_files(diff_details)
    filtered = diff_details.select do |k, _|
      k.end_with?(".rb") ||
      k.end_with?(".ru") ||
      k.end_with?(".rake") ||
      File.basename(k).in?(%w{Gemfile Rakefile})
    end
    filtered.reject do |k, _|
      k.end_with?("db/schema.rb")
    end
  end

  def linter_results(cmd, options = {})
    require 'awesome_spawn'

    # rubocop exits 1 both when there are errors and when there are style issues.
    #   Instead of relying on just exit_status, we check if there is anything
    #   on stderr.
    result = MiqToolsServices::MiniGit.call(branch.repo.path) do |git|
      git.temporarily_checkout(commits.last) do
        logger.info("#{self.class.name}##{__method__} Executing: #{AwesomeSpawn.build_command_line(cmd, options)}")
        AwesomeSpawn.run(cmd, :params => options, :chdir => branch.repo.path)
      end
    end
    raise result.error if result.exit_status == 1 && result.error.present?

    JSON.parse(result.output.chomp)
  end

  def rubocop_comments
    MessageBuilder.new(results, branch).comments
  end

  def write_to_github
    logger.info("#{self.class.name}##{__method__} Updating pull request #{pr} with rubocop comment.")

    branch.repo.with_github_service do |github|
      @github = github
      replace_rubocop_comments
    end
  end

  def replace_rubocop_comments
    github.replace_issue_comments(pr, rubocop_comments) do |old_comment|
      rubocop_comment?(old_comment)
    end
  end

  def rubocop_comment?(comment)
    comment.body.start_with?("<rubocop />")
  end
end
