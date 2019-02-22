FactoryBot.define do
  factory :repo do
    sequence(:name) { |n| "SomeUser/repo_#{n}" }
  end
end
