FactoryGirl.define do
  factory :project do
    sequence(:name) { |n| "ACME #{n}" }
    association :user
    repository_provider "github"
    sequence(:repository_id) { |n| n }

    after(:create) do |project, evaluator|
      project.docker_image = FactoryGirl.create(:docker_image)
      project.save!
    end
  end
end
