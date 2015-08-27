FactoryGirl.define do
  factory :repo do
    sequence(:name) { |n| "repo_#{n}" }
    path { "/path/to/repos/#{name}" }

    upstream_user "SomeUser"
  end
end
