module Backporting
  class Form
    def initialize(params)
      @params = params
    end

    def target_branch
      params[:target_branch]
    end

    def pull_request_ids
      params[:pull_request_ids]
    end

    def target_label
      "#{target_branch}/yes"
    end

    def next_label(success)
      suffix = success ? 'backported' : 'conflict'
      "#{target_branch}/#{suffix}"
    end

    private

    attr_reader :params
  end

  class Runner
    def initialize(repo, form)
      @repo = repo
      @form = form
    end

    def call
      repo.with_git_service do |git|
        @git = git
        git.checkout(form.target_branch)

        repo.with_github_service do |github|
          @github = github
          process_backports
        end
      end
    end

    private

    attr_reader :repo, :form, :git, :github

    def process_backports
      form.pull_request_ids.each do |id|
        pull_request = github.pull_requests.get(id)
        process_backport(pull_request)
      end
    end

    def process_backport(pull_request)
      comment = StringIO.new("Backporting to `#{form.target_branch}`:\n")
      status = process_cherry_pick(pull_request, comment)

      remove_existing_label(pull_request)
      github.add_issue_labels(pull_request.number, form.next_label(status))

      github.create_issue_comments(pull_request.number, comment.string)
    end

    def process_cherry_pick(pull_request, comment)
      git.cherry_pick(pull_request.merge_commit_sha, :x => true, :m => 1)
      git.push('origin', form.target_branch)

      comment.puts("```diff\n#{git.show}")
    rescue MiniGit::GitError
      git.cherry_pick('--abort')
      comment.puts("```diff\n#{git.diff}")

      false
    end

    # TODO: extract to github service
    def remove_existing_label(pull_request)
      github.issues.labels.remove(github.user, github.repo, pull_request.number,
                                  :label_name => form.target_label)
    end
  end
end
