require 'rugged'
require 'fileutils'

module GitService
  class Branch
    attr_reader :branch

    def initialize(branch)
      @branch = branch
    end

    def extract_file(path, dest_dir, merged = false)
      content = content_at(path, merged)
      return false unless content

      file_type, perm = filemode_at(path, merged)

      dest_file = File.join(dest_dir, path)
      FileUtils.mkdir_p(File.dirname(dest_file))
      case file_type
      when :regular_file
        # Use "wb" to prevent Encoding::UndefinedConversionError: "\xD0" from ASCII-8BIT to UTF-8
        File.write(dest_file, content, :mode => "wb", :perm => perm)
      when :symbolic_link
        # For symlinks, file permissions are 0 anyway, so we ignore them
        FileUtils.ln_sf(content, dest_file)

        # TODO: Handle following symlinks as an option, otherwise we could extract a symlink with no target
      when :git_link
        # git links (submodules) are not yet supported
        return false
      end

      true
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

    def content_at(path, merged = false)
      blob_at(path, merged).try(:content)
    end

    # Return file type and permissions
    #
    # Git stores file type and permissions in a subset of the POSIX layout:
    #   https://unix.stackexchange.com/a/450488
    # Extract them from this format into something more consumable
    #
    # @return [Symbol, Integer] Returns the file type and permissions
    def filemode_at(path, merged = false)
      mode = blob_data_for(path, merged).to_h.fetch(:filemode, 0o100644)
      mode = mode.to_s(8)
      type =
        case mode[0, 2]
        when "10" then :regular_file
        when "12" then :symbolic_link
        when "16" then :git_link
        else raise "Unknown file type in mode"
        end
      perm = mode[3, 3].to_i(8)

      return type, perm
    end

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
