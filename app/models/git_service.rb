require 'thread'
require 'minigit'

class GitService
  include ServiceMixin

  # All MiniGit methods return stdout which always has a trailing newline
  # that is never wanted, so remove it always.
  def delegate_to_service(method_name, *args)
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

  def new_commits(since_commit, ref = "HEAD")
    rev_list({:reverse => true}, "#{since_commit}..#{ref}").split("\n")
  end

  def commit_message(commit)
    log({:pretty => "fuller"}, "--stat", "-1", commit)
  end

  def ref_name(ref)
    name = rev_parse("--abbrev-ref", ref)
    name.empty? ? ref : name
  end

  def current_branch
    ref = ref_name("HEAD")
    ref == "HEAD" ? current_ref : ref
  end

  def current_ref
    rev_parse("HEAD")
  end

  def branches
    branch.split("\n").collect do |b|
      b = b[1..-1] if b.start_with?("*")
      b.strip
    end
  end

  def destroy_branch(branch_name)
    branch("-D", branch_name)
  end

  def diff_details(commit1, commit2 = nil)
    commit2 ||= commit1
    commit1   = "#{commit1}~"

    output = diff("--patience", "-U0", "--no-color", "#{commit1}..#{commit2}")

    ret = Hash.new { |h, k| h[k] = [] }
    path = line_number = nil
    output.lines.each_with_object(ret) do |line, h|
      case line
      when /^--- (?:a\/)?/
        next
      when /^\+\+\+ (?:b\/)?(.+)/
        path = $1.chomp
      when /^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@/
        line_number = $1.to_i
      when /^([ +-])/
        if $1 != "-"
          h[path] << line_number
          line_number += 1
        end
      end
    end
  end

  #
  # Pull Request specific methods
  #

  def self.pr_branch(pr_number)
    "pr/#{pr_number}"
  end
  delegate :pr_branch, :to => :class

  def self.pr_number(branch)
    branch.split("/").last.to_i
  end
  delegate :pr_number, :to => :class

  def self.pr_branch?(branch)
    branch =~ %r{^pr/\d+$}
  end

  def pr_branch?(branch = nil)
    branch ||= current_branch
    self.class.pr_branch?(branch)
  end

  def mergeable?(branch = nil, into_branch = "master")
    orig_branch = current_branch
    branch ||= orig_branch

    begin
      checkout(into_branch) unless orig_branch == into_branch
      begin
        merge("--no-commit", "--no-ff", branch)
      rescue MiniGit::GitError
        return false
      end
      return true
    ensure
      merge("--abort")
      checkout(orig_branch) unless orig_branch == into_branch
    end
  end

  def update_pr_branch(branch = nil, remote = "upstream")
    create_or_update_pr_branch(branch || current_branch, remote)
  end

  def create_pr_branch(branch, remote = "upstream")
    create_or_update_pr_branch(branch, remote)
  end

  private

  def create_or_update_pr_branch(branch, remote)
    fetch("-fu", remote, "refs/pull/#{pr_number(branch)}/head:#{branch}")
    reset("--hard")
  end
end
