class CommitMonitorHandlers::CommitRange::RubocopChecker
  include Sidekiq::Worker
  sidekiq_options :queue => :miq_bot

  def self.handled_branch_modes
    [:pr]
  end

  attr_reader :branch, :commits, :results, :github

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
      @results = rubocop_results(files)
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

  def rubocop_results(files)
    require 'awesome_spawn'

    cmd = "rubocop"
    params = {
      :format => "json",
      nil     => files
    }

    # rubocop exits 1 both when there are errors and when there are style issues.
    #   Instead of relying on just exit_status, we check if there is anything
    #   on stderr.
    result = MiqToolsServices::MiniGit.call(branch.repo.path) do |git|
      git.temporarily_checkout(commits.last) do
        logger.info("#{self.class.name}##{__method__} Executing: #{AwesomeSpawn.build_command_line(cmd, params)}")
        AwesomeSpawn.run(cmd, :params => params, :chdir => branch.repo.path)
      end
    end
    raise result.error if result.exit_status == 1 && result.error.present?

    JSON.parse(result.output.chomp)
  end

  def write_to_github
    logger.info("#{self.class.name}##{__method__} Updating pull request #{branch.pr_number} with rubocop comment.")

    new_comments = MessageBuilder.new(results, branch).messages

    branch.repo.with_github_service do |github|
      @github = github
      delete_github_comments(find_old_github_comments)
      write_github_comments(new_comments)
    end
  end

  def delete_github_comments(comments)
    github.delete_issue_comments(comments.collect(&:id))
  end

  def write_github_comments(comments)
    github.create_issue_comments(branch.pr_number, comments)
  end

  def find_old_github_comments
    github.select_issue_comments(branch.pr_number) do |comment|
      rubocop_comment?(comment)
    end
  end

  def rubocop_comment?(comment)
    comment.body.start_with?("<rubocop />")
  end
end
