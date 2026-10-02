FactoryBot.define do
  factory :issue do
    association :repo
    sequence(:number)
  end
end
