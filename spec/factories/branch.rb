require 'securerandom'

FactoryGirl.define do
  factory :branch do
    sequence(:name) { |n| "branch_#{n}" }
    commit_uri      { "https://example.com/#{repo.name}/commit/$commit" }
    last_commit     { SecureRandom.hex(40) }
    merge_target    "master"

    repo
  end

  factory :pr_branch, :parent => :branch do
    sequence(:name)     { |n| "prs/#{n}/head" }
    sequence(:pr_title) { |n| "PR title #{n}" }

    pull_request true
  end
end
