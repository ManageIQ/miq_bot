require 'rugged'
require 'csv'

class CommitMonitorHandlers::CommitRange::RubocopChecker
  include Sidekiq::Worker
  sidekiq_options :queue => :miq_bot_glacial

  include BranchWorkerMixin
  include CodeAnalysisMixin

  def self.handled_branch_modes
    [:pr]
  end

  attr_reader :results

  def perform(branch_id, _new_commits)
    return unless find_branch(branch_id, :pr)

    process_branch
  end

  private

  def process_branch
    run
  rescue GitService::UnmergeableError
    nil # Avoid working on unmergeable PRs
  end

  def run
    proton_messages = pronto_result
    comment_body = pronto_format(proton_messages)
    comments = create_comment(comment_body)
    replace_pronto_comments(comments)
  end

  def create_comment(body)
    header = ""

    header << pronto_tag
    header << "#{"Commit".pluralize(commits.length)} #{commit_range_text} checked with ruby #{RUBY_VERSION} and:\n\n"
    header << versions_table
    header << "\n\n"

    [header + body]
  end

  def replace_pronto_comments(pronto_comments)
    pr_url = "https://github.com/#{fq_repo_name}/pull/#{pr_number}"
    logger.info("Updating #{pr_url} with Pronto comment.")

    GithubService.replace_comments(fq_repo_name, pr_number, pronto_comments) do |old_comment|
      pronto_comment?(old_comment)
    end
  end

  def pronto_tag
    "<pronto />"
  end

  def pronto_comment?(comment)
    comment.body.start_with?(pronto_tag)
  end

  def versions_table
    CSV.generate(:col_sep => " | ") do |csv|
      csv << %w(Pronto\ Runners Version Linters Version) # header
      csv << %w(--- --- --- ---) # separator
      versions.each { |ver| csv << ver.to_a.flatten } # values
    end.delete("\\\"").strip # remove the unwanted \"
  end

  def gem_version(gem_name)
    Gem.loaded_specs[gem_name].version.to_s
  end

  def versions
    @versions ||= version_list
  end

  def version_list
    [
      { "pronto-rubocop" => gem_version("pronto-rubocop"), "rubocop" => gem_version("rubocop") },
      { "pronto-haml" => gem_version("pronto-haml"), "haml_lint" => gem_version("haml_lint") },
      { "pronto-yamllint" => gem_version("pronto-yamllint"), "yamllint" => Open3.capture3("yamllint -v")[1].strip.split(' ').last }
    ]
  end

  def pronto_format(messages)
    if messages.empty?
      looks_good
    else
      process(messages)
    end
  end

  def looks_good
    emoji = %w(:+1: :cookie: :star: :cake: :trophy: :ok_hand: :v: :tada:)

    "0 offenses detected :shipit:\nEverything looks fine. #{emoji.sample}"
  end

  # MiqBot's Formatter - transformation of array of Pronto::Message objects into human readable format (PR comment - body)
  def process(messages)
    offenses_count = messages.count
    files_count = messages.group_by(&:path).count

    string = "#{offenses_count} #{"offense".pluralize(offenses_count)} detected in #{files_count} #{"file".pluralize(files_count)}.\n\n---\n\n"

    messages.group_by(&:path).each do |file, msgs|
      string << "**[#{file}](#{url_file(msgs.first)})**\n"
      msgs.each do |msg|
        string << "- [ ] #{severity_to_emoji(msg.level)} - [Line #{msg.line.position}](#{url_file_line(msg)}) - #{msg.runner.to_s.sub!("Pronto::", '')} - #{msg.msg}\n"
      end
      string << "\n"
    end

    string.strip
  end

  def url_file(msg)
    commit = commits.last
    repo = fq_repo_name.split("/").last
    owner = branch.commit_uri.scan(/https:\/\/github.com\/([^\/]+)/).flatten.first

    "https://github.com/#{owner}/#{repo}/blob/#{commit}/#{msg.path}"
  end

  def url_file_line(msg)
    "#{url_file(msg)}#L#{msg.line.position}"
  end

  def severity_to_emoji(level)
    case level
    when :info
      ":information_source:"
    when :warning
      ":warning:"
    when :fatal, :error
      ":bomb: :boom: :fire: :fire_engine:"
    else
      ":sos: :no_entry:"
    end
  end
end
