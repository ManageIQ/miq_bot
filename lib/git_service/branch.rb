require 'rugged'

module GitService
  class Branch
    attr_reader :branch
    def initialize(branch)
      @branch = branch
    end

    def content_at(path, merged = false)
      blob_at(path, merged).try(:content)
    end

    def permission_for(path, merged = false)
      git_perm = blob_data_for(path, merged).to_h[:filemode]

      # Since git stores file permissions in a different format:
      #
      #   https://unix.stackexchange.com/a/450488
      #
      # Convert what we get from Rugged to something that will work with File
      #
      #   git_perm = 0o100755
      #   git_perm.to_s(8)
      #   #=> "100755"
      #   _.[-3,3]
      #   #=> "755"
      #   _.to_i(8)
      #   #=> 493
      #   0o755
      #   #=> 493
      #
      git_perm ? git_perm.to_s(8)[-3,3].to_i(8) : 0o644
    end

    def diff(merge_target = nil)
      Diff.new(target_for_reference(merge_target_ref_name(merge_target)).diff(merge_tree))
    end

    def exists?
      rugged_repo.branches.exists?(ref_name)
    end

    def mergeable?
      merge_tree
      true
    rescue UnmergeableError
      false
    end

    def merge_base(merge_target = nil)
      rugged_repo.merge_base(target_for_reference(merge_target_ref_name(merge_target)), target_for_reference(ref_name))
    end

    def merge_index(merge_target = nil) # Rugged::Index for a merge of this branch
      rugged_repo.merge_commits(target_for_reference(merge_target_ref_name(merge_target)), target_for_reference(ref_name))
    end

    def merge_tree # Rugged::Tree object for the merge of this branch
      tree_ref = merge_index.write_tree(rugged_repo)
      rugged_repo.lookup(tree_ref)
    rescue Rugged::IndexError
      raise UnmergeableError
    ensure
      # Rugged seems to allocate large C structures, but not many Ruby objects,
      #   and thus doesn't trigger a GC, so we will trigger one manually.
      GC.start
    end

    def tip_commit
      target_for_reference(ref_name)
    end

    def tip_tree
      tip_commit.tree
    end

    def target_for_reference(reference) # Rugged::Commit for a given refname i.e. "refs/remotes/origin/master"
      rugged_repo.references[reference].target
    end

    def tip_files
      list_files_in_tree(tip_tree.oid)
    end

    def commit_ids_since(starting_point)
      range_walker(starting_point).collect(&:oid).reverse
    end

    def commit(commit_oid)
      Commit.new(rugged_repo, commit_oid)
    end

    private

    def list_files_in_tree(rugged_tree_oid, current_path = Pathname.new(""))
      rugged_repo.lookup(rugged_tree_oid).each_with_object([]) do |i, files|
        full_path = current_path.join(i[:name])
        case i[:type]
        when :blob
          files << full_path.to_s
        when :tree
          files.concat(list_files_in_tree(i[:oid], full_path))
        end
      end
    end

    def range_walker(walk_start, walk_end = ref_name)
      Rugged::Walker.new(rugged_repo).tap do |walker|
        walker.push_range("#{walk_start}..#{walk_end}")
      end
    end

    def ref_name
      return "refs/#{branch.name}" if branch.name.include?("prs/")
      "refs/remotes/origin/#{branch.name}"
    end

    def merge_target_ref_name(merge_target = nil)
      ref = merge_target || branch.merge_target
      "refs/remotes/origin/#{ref}"
    end

    # Rugged::Blob object for a given file path on this branch
    def blob_at(path, merged = false)
      blob = Rugged::Blob.lookup(rugged_repo, blob_data_for(path, merged)[:oid])
      blob.type == :blob ? blob : nil
    rescue Rugged::TreeError
      nil
    end

    def blob_data_for(path, merged = false)
      source = merged ? merge_tree : tip_tree
      source.path(path)
    end

    def rugged_repo
      @rugged_repo ||= Rugged::Repository.new(branch.repo.path.to_s)
    end
  end
end
