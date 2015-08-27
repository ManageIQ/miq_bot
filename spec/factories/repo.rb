FactoryGirl.define do
  factory :repo do
    sequence(:name) { |n| "SomeUser/repo_#{n}" }
    path            { "/path/to/repos/#{name}" }
  end
end
