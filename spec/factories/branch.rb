require 'securerandom'

FactoryBot.define do
  factory :branch do
    sequence(:name) { |n| "branch_#{n}" }
    commit_uri      { "https://example.com/#{repo.name}/commit/$commit" }
    last_commit     { SecureRandom.hex(40) }

    repo
  end

  factory :pr_branch, :parent => :branch do
    sequence(:name)     { |n| "prs/#{n}/head" }
    sequence(:pr_title) { |n| "PR title #{n}" }
    merge_target        { "master" }

    pull_request        { true }
  end
end
