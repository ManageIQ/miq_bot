class CommitMonitorHandlers::CommitRange::RubocopChecker
  include Sidekiq::Worker

  def self.handled_branch_modes
    [:pr]
  end

  attr_reader :branch, :commits, :results, :github

  def perform(branch_id, new_commits)
    @branch  = CommitMonitorBranch.where(:id => branch_id).first
    @commits = @branch.commits_list

    if @branch.nil?
      logger.info("Branch #{branch_id} no longer exists.  Skipping.")
      return
    end
    unless @branch.pull_request?
      logger.info("Branch #{@branch.name} is not a pull request.  Skipping.")
      return
    end

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
      @results = filter_rubocop_results(@results, diff_details)
    end

    write_to_github
  end

  def diff_details_for_branch
    GitService.call(branch.repo.path) do |git|
      git.diff_details(commits.first, commits.last)
    end
  end

  def filter_ruby_files(diff_details)
    diff_details.select do |k, _|
      k.end_with?(".rb") ||
      k.end_with?(".ru") ||
      k.end_with?(".rake") ||
      k.in?(%w{Gemfile Rakefile})
    end
  end

  def rubocop_results(files)
    require 'awesome_spawn'

    cmd = "rubocop"
    params = {
      :config   => Rails.root.join("config/rubocop_checker.yml").to_s,
      :format   => "json",
      nil       => files
    }

    # rubocop exits 1 both when there are errors and when there are style issues.
    #   Instead of relying on just exit_status, we check if there is anything
    #   on stderr.
    result = GitService.call(branch.repo.path) do |git|
      git.temporarily_checkout(commits.last) do
        logger.info("#{self.class.name}##{__method__} Executing: #{AwesomeSpawn.build_command_line(cmd, params)}")
        AwesomeSpawn.run(cmd, :params => params, :chdir => branch.repo.path)
      end
    end
    raise result.error if result.exit_status == 1 && result.error.present?

    JSON.parse(result.output.chomp)
  end

  def filter_rubocop_results(results, diff_details)
    results["files"].each do |f|
      f["offences"].select! do |o|
        o["severity"].in?(["error", "fatal"]) ||
        diff_details[f["path"]].include?(o["location"]["line"])
      end
    end

    results["summary"]["offence_count"] =
      results["files"].inject(0) { |sum, f| sum + f["offences"].length }

    results
  end

  def write_to_github
    logger.info("#{self.class.name}##{__method__} Updating pull request #{branch.pr_number} with rubocop comment.")

    comments = MessageBuilder.new(results, branch).messages

    GithubService.call(:repo => branch.repo) do |github|
      @github = github
      clean_old_github_comments
      write_new_github_comments(comments)
    end
  end

  def clean_old_github_comments
    to_edit, to_delete = find_old_github_comments.partition do |comment|
      comment.body.split("\n").first.start_with?("Checked commit")
    end

    edit_old_github_comments(to_edit)
    delete_old_github_comments(to_delete)
  end

  def find_old_github_comments
    github.select_issue_comments(branch.pr_number) do |comment|
      body       = comment.body
      first_line = body.split("\n").first

      (first_line.start_with?("Checked commit") || first_line.include?("...continued")) &&
        !body.include?("outdated")
    end
  end

  def edit_old_github_comments(comments)
    comments.each do |comment|
      new_comment = comment.body.split("\n")[0, 2]
      new_comment << ""
      new_comment << "*This comment is on an outdated set of commits.*"

      github.edit_issue_comment(comment.id, new_comment.join("\n"))
    end
  end

  def write_new_github_comments(comments)
    github.create_issue_comments(branch.pr_number, comments)
  end

  def delete_old_github_comments(comments)
    github.delete_issue_comments(comments.collect(&:id))
  end
end
