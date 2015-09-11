require 'test_helper'

class UserTest < ActiveSupport::TestCase
  let(:user) { FactoryGirl.create(:user) }

  describe "organization_user_roles" do
    let(:organization_1) { FactoryGirl.create(:organization) }
    let(:organization_2) { FactoryGirl.create(:organization) }
    let(:organization_3) { FactoryGirl.create(:organization) }

    let(:admin_organization_role) do
      FactoryGirl.create(:organization_role, name: "admin")
    end

    let(:moderator_organization_role) do
      FactoryGirl.create(:organization_role, name: "moderator")
    end

    let(:participant_organization_role) do
      FactoryGirl.create(:organization_role, name: "participant")
    end

    before do
      user.organization_user_roles.create(organization: organization_1,
        organization_role: participant_organization_role)

      user.organization_user_roles.create(organization: organization_2,
        organization_role: admin_organization_role)

      organization_3
    end

    describe "roles_on_organization" do
      it "returns only the roles on the given organization" do
        user.roles_on_organization(organization_1).
          must_equal [participant_organization_role]

        user.roles_on_organization(organization_2).
          must_equal [admin_organization_role]

        user.roles_on_organization(organization_3).
          must_equal []
      end
    end

    describe "participating_organizations association" do
      it "returns only the organizations on which user has roles" do
        user.participating_organizations.sort.
          must_equal [organization_1, organization_2]

        user.organization_user_roles.create(organization: organization_3,
          organization_role: admin_organization_role)

        user.reload.participating_organizations.sort.
          must_equal [organization_1, organization_2, organization_3]
      end
    end
  end
end
