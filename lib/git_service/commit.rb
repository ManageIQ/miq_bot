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

    def formatted_author
      "#{rugged_commit.author[:name]} <#{rugged_commit.author[:email]}>"
    end

    def formatted_author_date
      rugged_commit.author[:time].to_time.strftime("%c %z")
    end

    def formatted_committer
      "#{rugged_commit.committer[:name]} <#{rugged_commit.committer[:email]}>"
    end

    def formatted_committer_date
      rugged_commit.committer[:time].to_time.strftime("%c %z")
    end

    # NOTE: really not needed, but keeps it consistent
    def formatted_commit_message
      rugged_commit.message
    end

    def formatted_commit_stats
      diff.file_status.map do |file, stats|
        file_stats  = file.dup
        file_stats << " | "
        file_stats << (stats[:additions].to_i + stats[:deletions].to_i).to_s
        file_stats << " "
        file_stats << "+" if stats[:additions].positive?
        file_stats << "-" if stats[:deletions].positive?
        file_stats
      end
    end

    def full_message
      message = "commit #{commit_oid}\n"
      message << "Merge: #{parent_oids.join(" ")}\n" if parent_oids.length > 1
      message << "Author:     #{formatted_author}\n"
      message << "AuthorDate: #{formatted_author_date}\n"
      message << "Commit:     #{formatted_committer}\n"
      message << "CommitDate: #{formatted_committer_date}\n"
      message << "\n"
      message << formatted_commit_message.indent(4)
      message << "\n"
      message << formatted_commit_stats.join("\n").indent(1)
      message << "\n #{diff.status_summary}"
      message
    end

    def details_hash
      {
        "sha"            => commit_oid,
        "parent_oids"    => parent_oids,
        "merge_commit?"  => parent_oids.length > 1,
        "author"         => formatted_author,
        "author_date"    => formatted_author_date,
        "commit"         => formatted_committer,
        "commit_date"    => formatted_committer_date,
        "message"        => formatted_commit_message,
        "files"          => diff.file_status.keys,
        "stats"          => formatted_commit_stats,
        "status_summary" => diff.status_summary
      }
    end
  end
end
