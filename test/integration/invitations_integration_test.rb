require 'test_helper'

class InvitationsIntegrationTest < Capybara::Rails::TestCase
  let(:organization) { FactoryGirl.create(:organization) }
  let(:owner) { organization.user }
  let(:participant) do
    user = FactoryGirl.create(:user)
    user.participating_organizations << organization

    user
  end

  describe "send invitation menu item" do
    it "shows the menu item when user is the owner of the current organization" do
      login_as owner, scope: :user
      visit root_path
      page.must_have_selector "a[href='/users/invitation/new']"
    end

    it "does not show the menu item when user is not the owner of the current organization" do
      login_as participant, scope: :user
      visit root_path
      page.wont_have_selector "a[href='/users/invitation/new']"
    end
  end
end
