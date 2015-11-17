FactoryGirl.define do
  factory :doorkeeper_access_token, class: Doorkeeper::AccessToken do
    token SecureRandom.hex
    association :application, factory: :doorkeeper_application
  end
end
