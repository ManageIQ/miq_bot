require 'securerandom'

FactoryGirl.define do
  factory :branch do
    sequence(:name) { |n| "branch_#{n}" }

    commit_uri  "https://example.com/foo/bar/commit/$commit"
    last_commit { SecureRandom.hex(40) }

    repo
  end

  factory :pr_branch, :parent => :branch do
    sequence(:name) { |n| "pr/#{n}" }

    pull_request true
  end
end
