require 'rugged'

module GitService
  class Branch
    attr_reader :branch
    def initialize(branch)
      @branch = branch
    end

    def blob_at(path) # Rugged::Blob object for a given file path on this branch
      blob_data = merge_tree.path(path)
      blob = Rugged::Blob.lookup(rugged_repo, blob_data[:oid])
      (blob.type == :blob) ? blob : nil
    rescue Rugged::TreeError
      nil
    end

    def diff
      Diff.new(target_for_reference(merge_target_ref_name).diff(merge_tree))
    end

    def mergeable?
      merge_tree
      true
    rescue Rugged::IndexError
      false
    end

    def merge_base
      rugged_repo.merge_base(target_for_reference(merge_target_ref_name), target_for_reference(ref_name))
    end

    def merge_index # Rugged::Index for a merge of this branch
      rugged_repo.merge_commits(target_for_reference(merge_target_ref_name), target_for_reference(ref_name))
    end

    def merge_tree # Rugged::Tree object for the merge of this branch
      tree_ref = merge_index.write_tree(rugged_repo)
      rugged_repo.lookup(tree_ref)
    ensure
      # Rugged seems to allocate large C structures, but not many Ruby objects,
      #   and thus doesn't trigger a GC, so we will trigger one manually.
      GC.start
    end

    def target_for_reference(reference) # Rugged::Commit for a given refname i.e. "refs/remotes/origin/master"
      rugged_repo.references[reference].target
    end

    private

    def ref_name
      return "refs/#{branch.name}" if branch.name.include?("prs/")
      "refs/remotes/origin/#{branch.name}"
    end

    def merge_target_ref_name
      "refs/remotes/origin/#{branch.merge_target}"
    end

    def rugged_repo
      @rugged_repo ||= Rugged::Repository.new(branch.repo.path.to_s)
    end
  end
end
