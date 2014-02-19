class CommitMonitorHandlers::CommitRange::RubocopChecker
  include Sidekiq::Worker

  def self.handled_branch_modes
    [:pr]
  end

  attr_reader :branch, :commits

  def perform(branch_id, commits)
    @branch = CommitMonitorBranch.find(branch_id)
    return unless @branch.pull_request?
    @commits = commits

    diff_details = filter_ruby_files(diff_details_for_commits)
    files        = diff_details.keys
    return if files.length == 0

    results = rubocop_results(files)
    results = filter_rubocop_results(results, diff_details)
    return if results["summary"]["offence_count"] == 0

    message = message_from_results(results)
    write_to_github(message)
  end

  private

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

    logger.info("#{self.class.name}##{__method__} Executing: #{AwesomeSpawn.build_command_line(cmd, params)}")

    # rubocop exits 1 both when there are errors and when there are style issues.
    #   Instead of relying on just exit_status, we check if there is anything
    #   on stderr.
    result = AwesomeSpawn.run(cmd, :params => params, :chdir => branch.repo.path)
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

  def message_from_results(results)
    message = StringIO.new

    commit_range = [
      branch.commit_uri_to(commits.first),
      branch.commit_uri_to(commits.last),
    ].uniq.join(" .. ")
    message.puts("Checked #{"commit".pluralize(commits.length)} #{commit_range}")

    file_count    = results["summary"]["target_file_count"]
    offence_count = results["summary"]["offence_count"]
    message.puts("#{file_count} #{"file".pluralize(file_count)} checked, #{offence_count} #{"offense".pluralize(offence_count)} detected")

    files = results["files"].sort_by { |f| f["path"] }
    files.each do |f|
      next if f["offences"].empty?

      message.puts
      message.puts("**#{f["path"]}**")
      message.puts("```")
      f["offences"].each do |o|
        message.printf("%5s:%3d:%3d: %s: %s\n",
          format_severity(o["severity"]),
          o["location"]["line"],
          o["location"]["column"],
          o["cop_name"],
          o["message"]
        )
      end
      message.puts("```")
    end

    message.string
  end

  def format_severity(sev)
    case sev
    when "convention" then "CONV"
    when "refactor"   then "REFAC"
    when "warning"    then "WARN"
    else sev.upcase
    end
  end

  def write_to_github(message)
    logger.info("#{self.class.name}##{__method__} Updating pull request #{branch.pr_number} with rubocop issues.")

    GithubService.call(:repo => branch.repo) do |github|
      github.issues.comments.create(
        :issue_id => branch.pr_number,
        :body     => message
      )
    end
  end
end
