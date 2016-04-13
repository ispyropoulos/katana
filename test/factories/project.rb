FactoryGirl.define do
  factory :project do
    sequence(:name) { |n| "ACME_#{n}" }
    association :user
    repository_provider "github"
    sequence(:repository_id) { |n| n }
    sequence(:repository_name) { |n| "ACME_#{n}" }

    after(:create) do |project, evaluator|
      project.docker_image = FactoryGirl.create(:docker_image)
      project.save!
    end
  end

  factory :public_project, class: Project do
    sequence(:name) { |n| "ACME_#{n}" }
    association :user
    repository_provider "github"
    is_private false
    sequence(:repository_id) { |n| n }
    sequence(:repository_name) { |n| "ACME_#{n}" }

    after(:create) do |project, evaluator|
      project.docker_image = FactoryGirl.create(:docker_image)
      project.save!
    end
  end
end
