class CommitMonitorHandlers::CommitRange::RubocopChecker
  include Sidekiq::Worker

  def self.handled_branch_modes
    [:pr]
  end

  attr_reader :branch, :commits

  def perform(branch_id, commits)
    @branch  = CommitMonitorBranch.where(:id => branch_id).first
    @commits = commits

    if @branch.nil?
      logger.info("Branch #{branch_id} no longer exists.  Skipping.")
      return
    end
    unless @branch.pull_request?
      logger.info("Branch #{@branch.name} is not a pull request.  Skipping.")
      return
    end

    process_commits
  end

  private

  def process_commits
    diff_details = filter_ruby_files(diff_details_for_commits)
    files        = diff_details.keys
    return if files.length == 0

    results = rubocop_results(files)
    results = filter_rubocop_results(results, diff_details)
    return if results["summary"]["offence_count"] == 0

    messages = MessageBuilder.new(results, branch, commits).messages
    write_to_github(messages)
  end

  def diff_details_for_commits
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

  def write_to_github(messages)
    logger.info("#{self.class.name}##{__method__} Updating pull request #{branch.pr_number} with rubocop issues.")

    GithubService.call(:repo => branch.repo) do |github|
      Array(messages).each do |message|
        github.issues.comments.create(
          :issue_id => branch.pr_number,
          :body     => message
        )
      end
    end
  end
end
