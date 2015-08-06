FactoryGirl.define do
  factory :branch, :class => CommitMonitorBranch do
    sequence(:name)  { |n| "feature/foo#{n}" }
    commit_uri { "https://example.com/foo/bar/commit/#{Digest::SHA1.hexdigest 'foo'}" }
    last_commit "123456"
    repo
  end
end
