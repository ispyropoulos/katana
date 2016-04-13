require 'test_helper'

class PublicRepositoryFeatureTest < Capybara::Rails::TestCase

  describe 'Importing a Github public repository' do
    let(:user) { FactoryGirl.create(:user, projects_limit: 10) }
    let(:repo_name) { 'ispyropoulos/intl-tel-input-rails' }

    before do
      login_as user, scope: :user
    end

    it "creates a github project with correct attributes after successful completion", js: true do
      VCR.use_cassette 'repos'  do
        visit project_wizard_path(:select_repository)
        page.must_have_content "GitHub"
        find('label', text: "GitHub").click
        page.must_have_content repo_name
        click_on repo_name
      end

      wait_for_requests_to_finish
      project = Project.last
      project.repository_provider.must_equal 'github'
      project.repository_name.must_equal 'intl-tel-input-rails'
      project.repository_owner.must_equal 'ispyropoulos'
      project.is_private.must_equal false
    end
  end

  describe 'Importing a Bitbucket public repository' do
    let(:bitbucket_user) { FactoryGirl.create(:bitbucket_user, projects_limit: 10) }
    let(:repo_name) { 'spyros_brilis/testing_repository' }

    before do
      login_as bitbucket_user, scope: :user
    end

    it "creates a bitbucket project with correct attributes after successful completion", js: true do

      VCR.use_cassette 'bitbucket_import_repo' do
        visit project_wizard_path(:select_repository)
        page.must_have_content "Select a repository provider:"
        find(".fa-bitbucket").click
        page.must_have_content repo_name
        click_on repo_name
        wait_for_requests_to_finish
      end

      project = Project.last
      project.repository_provider.must_equal 'bitbucket'
      project.repository_name.must_equal 'testing_repository'
      project.repository_owner.must_equal 'spyros_brilis'
      project.is_private.must_equal false
    end
  end

  describe 'visiting a pulbic project/show page XX' do
    let(:public_project) { FactoryGirl.create(:public_project) }

    it 'does not display track_branch action' do
      visit project_path(public_project.id)
      page.all('.breadcrumb-actions').size.must_equal 0
    end
  end
end
