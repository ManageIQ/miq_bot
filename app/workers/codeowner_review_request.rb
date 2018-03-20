require 'pry'
require 'pry-byebug'

class PullRequestMonitorHandlers::CodeownerReviewRequest
  include Sidekiq::Worker
  sidekiq_options :queue => :miq_bot

  include BranchWorkerMixin

  def perform(branch_id)
    return unless find_branch(branch_id, :pr)

    init
  end

  private

  def init

    binding.pry

    pr_data = load_pull_request()

=begin
    pr_data = {
      :user => "@user",
      :repository => "owner/repository",
      :files => [
        "file1.rb",
        "file2.rb",
        "folder/file.txt",
        "file.yaml"
      ]
    }
=end

    # TODO: git fetch the repository (branch.repo.git_fetch is dangerous (in this case probably))
    dir = repo.path.to_s

    x = Rugged::Repository.new(dir)
    x.remotes['origin'].fetch("pull/#{pr_number}/head")

    # TODO:
    # 1) create rugged repo from repo.path.to_s
    # 2) fetch this rugged repo
    # 3) get codeowners from this repo
    # 4) load it

    # TODO: maybe there is other way how to get CODEOWNERS content
    co_path = Find.find(dir).find { |path| path.include?('CODEOWNERS') && File.file?(path) }
    return if co_path.nil?

    co_data = codeowners_load(co_path)
    return if co_data.nil?

=begin
    co_data = [
      {
        :pattern => "*",
        :users=>["@europ"]
      },
      {
        :pattern => "folder_a/",
        :users=>["@tumido", "@romanblanco"]
      },
      {
        :pattern => "*.rb",
        :users=>["@skateman"]
      }
    ]
=end

    codeowners_expand(dir, co_data)

    reviewers = find_reviewers(co_data, pr_data)
    return if reviewers.empty?

    send_request(reviewers)
  end

  def send_request(users)
    users.each { |user| user.slice!(0) if user.starts_with?("@") }
    GithubService.request_pull_request_review(fq_repo_name, pr_number, users)
  end

  def find_reviewers(co_data, pr_data)
    reviewers = []

    unless pr_data[:files].empty?
      pr_data[:files].each do |pr_file|
        co_data.each do |co_element|
          if co_element[:pattern].eql?("*")
            reviewers |= co_element[:users].select{ |user| user != pr_data[:user] }
          else
            co_element[:files].each do |co_file|
              if co_file.end_with?(pr_file)
                reviewers |= co_element[:users].select{ |user| user != pr_data[:user] }
              end
            end
          end
        end
      end
    end

    reviewers
  end

  def load_pull_request()
    {
      :user => "@" + branch.commit_uri.scan(/https:\/\/github.com\/([^\/]+).*/).first.first, # tmp solution for "author"
      :repository => fq_repo_name, # "owner/repository"
      :files => diff_file_names # [file1, file2, fileN]
    }
  end

  # load the content of CODEOWNERS
  def codeowners_load(file_path)
    File.readlines(file_path).map do |line|
      next if line.starts_with?('#') or line.blank?
      content = line.match(/^(?<path>[\S]+)(?:\s+)(?<users>(?:@\S+\s*)+).*$/)
      { :pattern => content[:path], :users => content[:users].strip.split(/\s+/) } if content[:path] && content[:users]
    end.compact
  end

  # adds an array of file paths matching the pattern defined in codeowners
  def codeowners_expand(dir, co_data)
    co_data.each do |element|
      element[:files] = expand_path(dir, element[:pattern])
    end
  end

  # find every file path which will match the path pattern
  def expand_path(dir, path)
    dir << "/" if not dir.end_with?("/") # dir/
    path.slice!(0) if path.start_with?("/") # path
    target = (dir+path).gsub(/\/+/, "/") # dir/path

    if File.file?(target)
      return Array(path.gsub(/\/+/, "/"))
    elsif File.directory?(target)
      return Dir.glob(dir+path+"/**/*").map { |filepath| filepath.gsub(/\/+/, "/").sub(dir, '') }
    elsif path.include?("*")
      return expand_path_including_asterisk(dir, path)
    end
  end

  # path pattern with '*'
  def expand_path_including_asterisk(dir, path)
    files = []

    pattern = path.split("*")
    prefix = pattern.empty? ? "" : pattern.first
    suffix = pattern.count == 2 ? pattern.last : ""

    Dir.glob(dir+prefix+"**/*").each do |filepath|
      unless suffix.empty? # prefix*suffix
        filepath.end_with?(suffix) ? files << filepath.gsub(/\/+/, "/").sub(dir, '') : next
      else # prefix*
        files << filepath.gsub(/\/+/, "/").sub(dir, '')
      end
    end

    files
  end
end
