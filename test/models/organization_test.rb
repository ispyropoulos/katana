require 'test_helper'

class OrganizationTest < ActiveSupport::TestCase
  describe "organization_limit on user" do
    let(:user) { FactoryGirl.create(:user, organizations_limit: 1) }
    let(:organization) { FactoryGirl.create(:organization, user: user) }

    before { organization }

    it "won't assign to a user who reached the organizatinos_limit" do
      organization2 = FactoryGirl.build(:organization, user: user)
      assert_not organization2.save
      assert organization2.errors.keys.include?(:base)
    end
  end
end
