module MiqToolsServices
  class MiniGit
    include ServiceMixin

    def self.clone(*args)
      require 'awesome_spawn'
      STDERR.puts "+ #{AwesomeSpawn.build_command_line("git clone", args)}"
      STDERR.puts AwesomeSpawn.run!("git clone", :params => args).output
      true
    rescue AwesomeSpawn::CommandResultError => err
      require 'minigit'
      raise ::MiniGit::GitError.new(["clone"], err.result.error.chomp)
    end

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
        require 'minigit'
        ::MiniGit.debug = true
        ::MiniGit::Capturing.new(File.expand_path(path_to_repo))
      end
    end

    def bugzilla_ids(ref)
      Bugzilla.ids_in_git_commit_message(commit_message(ref))
    end

    def temporarily_checkout(ref)
      ref      = ref_name(ref)
      orig_ref = current_branch
      checkout(ref) unless ref == orig_ref
      yield
    ensure
      checkout(orig_ref) unless ref == orig_ref
    end

    def new_commits(since_commit, ref = "HEAD")
      rev_list({:reverse => true}, "#{since_commit}..#{ref}").split("\n")
    end

    def commit_message(commit)
      show({:pretty => "fuller"}, "--stat", "--summary", commit)
    end

    def ref_name(ref)
      name = rev_parse("--abbrev-ref", ref)
      name.empty? ? ref : name
    end

    def author_name(ref)
      log("-1", "--format=\"%an\"", ref)
    end

    def author_email(ref)
      log("-1", "--format=\"%ae\"", ref)
    end

    def subject(ref)
      log("-1", "--format=\"%s\"", ref)
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
      if commit2.nil?
        commit2 = commit1
        commit1 = "#{commit1}~"
      end
      output = diff("--patience", "-U0", "--no-color", "#{commit1}...#{commit2}")

      ret = Hash.new { |h, k| h[k] = [] }
      path = line_number = nil
      output.each_line do |line|
        # Note: We are intentionally ignoring deletes "-" for now
        case line
        when /^--- (?:a\/)?/
          next
        when /^\+\+\+ (?:b\/)?(.+)/
          path = $1.chomp
        when /^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@/
          line_number = $1.to_i
        when /^[ +]/
          ret[path] << line_number
          line_number += 1
        end
      end
      ret
    end

    def diff_file_names(commit1, commit2 = nil)
      if commit2.nil?
        commit2 = commit1
        commit1 = "#{commit1}~"
      end
      diff("--name-only", "#{commit1}...#{commit2}").split
    end

    #
    # Pull Request specific methods
    #

    def self.pr_branch(pr_number)
      "prs/#{pr_number}/head"
    end
    delegate :pr_branch, :to => :class

    def self.pr_number(branch)
      branch.split("/")[1].to_i
    end
    delegate :pr_number, :to => :class

    def mergeable?(branch = nil, into_branch = "master")
      branch ||= current_branch

      temporarily_checkout(into_branch) do
        begin
          merge("--no-commit", "--no-ff", branch)
          return true
        rescue ::MiniGit::GitError
          return false
        ensure
          merge("--abort")
        end
      end
    end

    def remotes
      remote.split("\n").uniq.compact
    end

    def fetches(remote)
      config("--get-all", "remote.#{remote}.fetch").split("\n").compact
    end

    def ensure_prs_refs
      remotes.each do |remote_name|
        config("--add", "remote.#{remote_name}.fetch", "+refs/pull/*:refs/prs/*") unless fetches(remote_name).include?("+refs/pull/*:refs/prs/*")
      end
    end
  end
end
