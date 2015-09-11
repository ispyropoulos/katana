require 'test_helper'

class OrganizationTest < ActiveSupport::TestCase
  let(:user) { FactoryGirl.create(:user, organizations_limit: 1) }
  let(:organization) { FactoryGirl.create(:organization, user: user) }

  describe "organization_limit on user" do
    before { organization }

    it "won't assign to a user who reached the organizatinos_limit" do
      organization2 = FactoryGirl.build(:organization, user: user)
      assert_not organization2.save
      assert organization2.errors.keys.include?(:base)
    end
  end

  describe "invited_users association" do
    let(:invited_user) do
      User.invite!({ email: 'invited_user@example.com'}, organization)
    end

    before { invited_user }

    it "returns users with invitations" do
      organization.invited_users.must_equal [invited_user]
    end

    describe "after user accepting the invitation" do
      before do
        User.accept_invitation!(:invitation_token => invited_user.raw_invitation_token,
          :password => "12345678")
      end

      it "still returns the invited user" do
        organization.reload.invited_users.must_equal [invited_user]
      end
    end
  end
end
