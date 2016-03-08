FactoryGirl.define do
  factory :testributor_run, class: 'TestRun' do
    association :tracked_branch
    commit_sha "123456"
    commit_message 'Test commit'
    commit_timestamp 1.day.ago
    commit_url 'https://github.com/ispyropoulos/katana/commit/f1e76db6eea4be210078e28a4491dff5613504b2'
    commit_author_name 'Donald Duck'
    commit_author_email 'test@example.com'
    commit_author_username 'donaldduck'
    commit_committer_name 'Donald Duck'
    commit_committer_email 'test@example.com'
    commit_committer_username 'donaldduck'
    status TestStatus::SETUP

    before(:build, :create) do |run, evaluator|
      if evaluator.tracked_branch && run.project.blank?
        run.project = evaluator.tracked_branch.project
      end
    end

    trait :queued do
      status TestStatus::QUEUED
    end

    trait :failed do
      status TestStatus::FAILED
    end

    trait :passed do
      status TestStatus::PASSED
    end

    trait :error do
      status TestStatus::ERROR
    end

    trait :cancelled do
      status TestStatus::CANCELLED
    end
  end
end
