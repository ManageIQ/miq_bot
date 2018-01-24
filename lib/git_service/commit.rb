module GitService
  class Commit
    attr_reader :commit_oid, :rugged_repo
    def initialize(rugged_repo, commit_oid)
      @commit_oid  = commit_oid
      @rugged_repo = rugged_repo
    end

    def diff(other_ref = parent_oids.first)
      Diff.new(rugged_diff(other_ref))
    end

    def parent_oids
      @parent_oids ||= rugged_commit.parent_oids
    end

    def rugged_commit
      @rugged_commit ||= Rugged::Commit.lookup(rugged_repo, commit_oid)
    end

    def rugged_diff(other_ref = parent_oids.first)
      other_commit = Rugged::Commit.lookup(rugged_repo, other_ref)
      other_commit.diff(rugged_commit)
    end

    def full_message
      message = "commit #{commit_oid}\n"
      message << "Merge: #{parent_oids.join(" ")}\n" if parent_oids.length > 1
      message << "Author:     #{rugged_commit.author[:name]} <#{rugged_commit.author[:email]}>\n"
      message << "AuthorDate: #{rugged_commit.author[:time].to_time.strftime("%c %z")}>\n"
      message << "Commit:     #{rugged_commit.author[:name]} <#{rugged_commit.author[:email]}>\n"
      message << "CommitDate: #{rugged_commit.author[:time].to_time.strftime("%c %z")}>\n"
      message << "\n"
      message << rugged_commit.message.indent(4)
      message << "\n"
      diff.file_status.each do |file, stats|
        message << " #{file} | #{stats[:additions].to_i + stats[:deletions].to_i} #{"+" * stats[:additions]}#{"-" * stats[:deletions]}\n"
      end
      message << " #{diff.status_summary}"
      message
    end
  end
end
