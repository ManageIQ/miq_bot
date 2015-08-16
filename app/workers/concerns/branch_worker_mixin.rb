module BranchWorkerMixin
  attr_reader :branch

  delegate :pr_number, :to => :branch

  def find_branch(branch_id, required_mode = nil)
    @branch = Branch.where(:id => branch_id).first

    if @branch.nil?
      logger.warn("Branch #{branch_id} no longer exists.  Skipping.")
      return false
    end

    if required_mode && @branch.mode != required_mode
      logger.error("Branch #{branch_id} is not a #{required_mode} branch.  Skipping.")
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

  def branch_enabled?
    setting = self.class.name.split("::").last.underscore.to_sym
    branch.enabled_for?(setting)
  end

  def verify_branch_enabled
    branch_enabled?.tap do |enabled|
      logger.warn("#{branch.repo.fq_name} has not been enabled.  Skipping.") unless enabled
    end
  end
end
