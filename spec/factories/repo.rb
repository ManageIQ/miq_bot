FactoryGirl.define do
  factory :repo, :class => CommitMonitorRepo do
    sequence(:name) { |n| "repo_#{n}"}
    sequence(:path) { |n| "/path/to/repos/#{name}" }
  end
end
