module GitService
  class Diff
    attr_reader :raw_diff
    def initialize(raw_diff)
      @raw_diff = raw_diff
    end

    def new_files
      raw_diff.deltas.collect { |delta| delta.try(:new_file).try(:[], :path) }.compact
    end

    def with_each_patch
      raw_diff.patches.each { |patch| yield(patch) }
    end

    def with_each_hunk
      with_each_patch do |patch|
        patch.hunks.each { |hunk| yield(hunk, patch) }
      end
    end

    def with_each_line
      with_each_hunk do |hunk, parent_patch|
        hunk.lines.each { |line| yield(line, hunk, parent_patch) }
      end
    end

    def file_status
      raw_diff.patches.each_with_object({}) do |patch, h|
        if new_file = patch.delta.new_file.try(:[], :path)
          additions = h.fetch_path(new_file, :additions) || 0
          h.store_path(new_file, :additions, (additions + patch.additions))
        end
        if old_file = patch.delta.old_file.try(:[], :path)
          deletions = h.fetch_path(old_file, :deletions) || 0
          h.store_path(new_file, :deletions, (deletions + patch.deletions))
        end
      end
    end

    def status_summary
      changed, added, deleted = raw_diff.stat
      [
        changed.positive? ? "#{changed} #{"file".pluralize(changed)} changed" : nil,
        added.positive? ? "#{added} #{"insertion".pluralize(added)}(+)" : nil,
        deleted.positive? ? "#{deleted} #{"deletion".pluralize(deleted)}(-)" : nil
      ].compact.join(", ")
    end
  end
end
