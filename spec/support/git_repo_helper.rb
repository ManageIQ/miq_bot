require 'rugged'

module GitRepoHelper
  # NOTE:  This ripped from the work I did in  `juliancheal/code-extractor`:
  #
  #     https://github.com/juliancheal/code-extractor/pull/11
  #
  # (from the test/test_helper.rb)
  #
  # Which that was a modified form of the fake_ansible_repo.rb spec helper from
  # the ManageIQ project:
  #
  #     https://github.com/ManageIQ/manageiq/blob/f8e70535/spec/support/fake_ansible_repo.rb
  #
  # It is being repurposed here to allow generating test repos in the specs
  # without needing to do live clones, allowing for the testing of git actions
  # in the specs.
  #
  # = TmpRepo
  #
  # This helper uses Rugged to create a stub git project for testing against
  # with a configurable file structure.  To generate a repo, you just needs to
  # be given a repo_path and a file tree definition.
  #
  #     file_tree_definition = %w[
  #       foo/one.txt
  #       bar/baz/two.txt
  #       qux/
  #       README.md
  #     ]
  #     TmpRepo.generate "/path/to/my_repo", file_tree_definition
  #
  #
  # == File Tree Definition
  #
  # The file tree definition (file_struct) is just passed in as a word array for
  # each file/empty-dir entry for the repo.
  #
  # So for a single file repo with a `foo.txt` plain text file, the definition
  # as an array would be:
  #
  #     file_struct = %w[
  #       foo.txt
  #     ]
  #
  # This will generate a repo with a single file called `foo.txt`.  For a more
  # complex example:
  #
  #     file_struct = %w[
  #       bin/foo
  #       lib/foo.rb
  #       lib/foo/version.rb
  #       test/test_helper.rb
  #       test/foo_test.rb
  #       tmp/
  #       LICENSE
  #       README.md
  #     ]
  #
  # NOTE:  directories only need to be defined on their own if they are intended
  # to be empty, otherwise a defining files in them is enough.
  #
  # == DSL methods
  #
  # When calling `TmpRepo.generate`, you can also pass a block to add content
  # to files, move/remove files and directories, and make/tag commits as
  # needed.
  #
  #   repo_structure = %w[
  #     foo/bar
  #     baz
  #   ]
  #
  #   TmpRepo.generate dir, repo_structure do
  #     update_file "foo/bar", "Bar Content"
  #     commit "add Bar content"
  #     tag "v1.0"
  #
  #     add_file "qux", "QUX!!!"
  #     commit
  #     tag "v2.0"
  #   end
  #
  class TmpRepo
    attr_accessor :repo
    attr_reader   :file_struct, :last_commit, :repo_path, :index

    delegate :create_branch, :checkout, :to => :repo

    def self.generate(repo_path, file_struct = [], &block)
      repo = new(repo_path, file_struct)
      repo.generate(&block)
      repo
    end

    def initialize(repo_path, file_struct)
      @commit_count = 0
      @repo_path    = Pathname.new(repo_path)
      @name         = @repo_path.basename
      @file_struct  = file_struct
      @last_commit  = nil
    end

    def generate(&block)
      build_repo

      git_init
      git_commit_initial

      execute(&block) if block_given?
    end

    def clone(url, &block)
      @repo        = Rugged::Repository.clone_at(url, @repo_path.to_s)
      @index       = repo.index
      @last_commit = repo.last_commit

      execute(&block) if block_given?
    end

    # Run DSL methods for given TestRepo instance
    def execute(&block)
      instance_eval(&block)
    end

    def create_remote(name, dir)
      Rugged::Repository.init_at dir, true      # create bare repo dir
      repo.remotes.create(name, dir)            # add bare repo dir as remote
      repo.remotes[name].push [repo.head.name]  # push current head to remote
    end

    # Commit with all changes added to the index
    #
    #   $ git add . && git commit -am "${msg}"
    #
    def commit(msg = nil)
      git_add_all
      @commit_count += 1

      @last_commit = Rugged::Commit.create(
        repo,
        :message    => msg || "Commit ##{@commit_count}",
        :parents    => [@last_commit].compact,
        :tree       => index.write_tree(repo),
        :update_ref => "HEAD"
      )
    end

    def tag(tag_name)
      repo.tags.create tag_name, @last_commit
    end

    # Add (or update) a file in the repo, and optionally write content to it
    #
    # The content is optional, but it will fully overwrite the content
    # currently in the file.
    #
    def add_file(entry, content = nil)
      path          = repo_path.join entry
      dir, filename = path.split unless entry.end_with? "/"

      FileUtils.mkdir_p dir.to_s == '.' ? repo_path : dir
      FileUtils.touch path     if filename
      File.write path, content if filename && content
    end
    alias update_file add_file

    # Prepends content to an existing file
    #
    def add_to_file(entry, content)
      path = repo_path.join entry
      File.write path, content, :mode => "a"
    end

    def current_branch_name
      repo.head.name.sub(/^refs\/heads\//, '')
    end

    private

    # Generate repo structure based on @file_struct array
    #
    # By providing a directory location and an array of paths to generate,
    # this will build a repository directory structure.  If a specific entry
    # ends with a '/', then an empty directory will be generated.
    #
    # Example file structure array:
    #
    #     file_struct = %w[
    #       foo/one.txt
    #       bar/two.txt
    #       baz/
    #       qux.txt
    #     ]
    #
    def build_repo
      file_struct.each do |entry|
        add_file entry
      end
    end

    # Init new repo at local_repo
    #
    #   $ cd /tmp/clone_dir/test_repo && git init .
    #
    def git_init
      @repo  = Rugged::Repository.init_at repo_path.to_s
      @index = repo.index
    end

    # Add new files to index
    #
    #   $ git add .
    #
    def git_add_all
      index.add_all
      index.write
    end

    # Create initial commit
    #
    #   $ git commit -m "Initial Commit"
    #
    def git_commit_initial
      commit "Initial Commit"
    end
  end
end
