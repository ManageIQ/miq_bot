FactoryGirl.define do
  factory :repo, :class => CommitMonitorRepo do
    sequence(:name) { |n| "Repo #{n}"}
    sequence(:path) { |n| "foo #{n}" }
  end
end
