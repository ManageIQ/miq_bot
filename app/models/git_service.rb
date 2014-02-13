require 'thread'
require 'minigit'

class GitService
  include ServiceMixin

  # All MiniGit methods return stdout which always has a trailing newline
  # that is never wanted, so remove it always.
  def method_missing(*args)
    super.chomp
  end

  attr_reader :path_to_repo

  def initialize(path_to_repo)
    @path_to_repo = path_to_repo
    service # initialize the service
  end

  def service
    @service ||= begin
      MiniGit.debug = true
      MiniGit::Capturing.new(File.expand_path(path_to_repo))
    end
  end

  def new_commits(since_commit)
    rev_list({:reverse => true}, "#{since_commit}..HEAD").split("\n")
  end

  def commit_message(commit)
    log({:pretty => "fuller"}, "--stat", "-1", commit)
  end

  def branches
    branch.split("\n").collect do |b|
      b = b[1..-1] if b.start_with?("*")
      b.strip
    end
  end

  def pr_branch_name(pr_number)
    "pr/#{pr_number}"
  end

  def pr_number(branch_name)
    branch_name.split("/").last.to_i
  end

  def pull_pr_branch(branch_name, remote = "upstream")
    fetch("-fu", remote, "refs/pull/#{pr_number(branch_name)}/head:#{branch_name}")
  end
  alias_method :create_pr_branch, :pull_pr_branch
end
