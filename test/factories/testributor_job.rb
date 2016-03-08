FactoryGirl.define do
  factory :testributor_job, class: 'TestJob' do
    association :test_run, factory: :testributor_run
    sequence(:command){|n| "bin/rake test test/models/model_#{n}_test.rb"}
    result ''
    status TestStatus::QUEUED
    test_errors 0
    failures 0
    count 0
    assertions 0
    skips 0

    trait :failed do
      status TestStatus::FAILED
    end

    trait :error do
      status TestStatus::ERROR
    end

    trait :cancelled do
      status TestStatus::CANCELLED
    end
  end
end
