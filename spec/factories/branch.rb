FactoryGirl.define do
  factory :branch, :class => CommitMonitorBranch do
    sequence(:name)  { |n| "fix/issue/#{n}" }
    commit_uri "https://example.com/foo/bar/commit/$commit"
    last_commit Digest::SHA1.hexdigest "contents of last commit"
    repo
  end
end
