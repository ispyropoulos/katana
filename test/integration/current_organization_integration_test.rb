require 'test_helper'

class CurrentOrganizationIntegrationTest < ActionDispatch::IntegrationTest
  describe "when user is not logged in" do
    it "does not assign @current_organization" do
      get root_path
      assigns[:current_organization].must_be_nil
    end
  end

  describe "when user is logged in" do
    let(:user) { FactoryGirl.create(:user) }

    before { login_as user, scope: :user }

    it "does not assign @current_organization when no organization exists" do
      get root_path
      assigns[:current_organization].must_be_nil
    end

    describe "when user is organization owner" do
      it "assigns @current_organization" do
        organization = FactoryGirl.create(:organization, user: user)
        get root_path
        assigns[:current_organization].must_equal organization
      end
    end

    describe "when user is an organization participant" do
      it "assigns @current_organization" do
        organization = FactoryGirl.create(:organization, user: user)
      end
    end
  end
end
