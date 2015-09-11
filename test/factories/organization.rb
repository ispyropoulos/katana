FactoryGirl.define do
  factory :organization do
    sequence(:name) { |n| "ACME #{n}" }
    association :user
  end
end
