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
  end
end
