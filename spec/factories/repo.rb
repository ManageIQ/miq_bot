FactoryGirl.define do
  factory :repo, :class => CommitMonitorRepo do
    sequence(:name) { |n| "repo_#{n}" }
    path { "/path/to/repos/#{name}" }
  end
end
