FactoryGirl.define do
  factory :user do
    sequence(:email) { |n| "person#{n}@example.com" }
    password '12345678'
    password_confirmation '12345678'
    confirmed_at Date.current
    projects_limit 1
    # For these keys to work, the key in attr_encrypted_options should match
    # the one that created them. For this reason we have a hardcoded key
    # when in test environment in app/models/user.rb
    encrypted_github_access_token "Mw77WrzI2zywus5kPmpt+abo9UPMgIY6zCowzAFrf3kxDCyWVk8LMH7vLyUh\ngKr1\n"
    encrypted_github_access_token_salt "c5301a0e89a217ab"
    encrypted_github_access_token_iv "7Q6SiUycJvz+S6/6mXhGQg==\n"
  end

  factory :bitbucket_user, class: User do
    sequence(:email) { |n| "bitbucket_person#{n}@example.com" }
    password '12345678'
    password_confirmation '12345678'
    confirmed_at Date.current
    projects_limit 1
    bitbucket_access_token "zX4dt9nfH5QVkKvnXH"
    bitbucket_access_token_secret "sDXvhTxed8npRZEejazuxxTPSUFr7Y6D"
  end
end
