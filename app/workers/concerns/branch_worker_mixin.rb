module BranchWorkerMixin
  extend ActiveSupport::Concern
  include SidekiqWorkerMixin

  attr_accessor :branch

  delegate :repo,
           :fq_repo_name,
           :fq_branch_name,
           :git_service,
           :pr_number,
           :pr_title,
           :pr_title_tags,
           :merge_target,
           :to => :branch

  def find_branch(branch_id, required_mode = nil)
    @branch ||= Branch.where(:id => branch_id).first

    if branch.nil?
      logger.warn("Branch #{branch_id} no longer exists.  Skipping.")
      return false
    end

    if required_mode && branch.mode != required_mode
      logger.error("Branch #{fq_branch_name} is not a #{required_mode} branch.  Skipping.")
      return false
    end

    unless enabled_for?(repo)
      logger.error("Branch #{fq_branch_name} is not enabled.  Skipping.")
      return false
    end

    true
  end

  def commits
    branch.commits_list
  end

  def commit_range
    [commits.first, commits.last]
  end

  def commit_range_text
    case commit_range.uniq.length
    when 1 then branch.commit_uri_to(commit_range.first)
    when 2 then branch.compare_uri_for(*commit_range)
    end
  end

  def diff_details_for_merge
    repo.with_git_service do |git|
      git.diff_details(branch.local_merge_target, commits.last)
    end
  end

  def diff_file_names
    @diff_file_names ||= git_service.diff.new_files
  end
end
