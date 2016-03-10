require 'test_helper'

class AddProjectPaginationFeatureTest < Capybara::Rails::TestCase
  let(:user) { FactoryGirl.create(:user) }

  before do
    login_as user, scope: :user
  end

  describe 'when user has more than one page of projects' do
    before do
      # instead of creating 60 projects we change the number
      # of fetched projects because we already have 11
      GithubRepositoryManager.send(:remove_const, :REPOSITORIES_PER_PAGE)
      GithubRepositoryManager.const_set(:REPOSITORIES_PER_PAGE, 3)
      ProjectWizard.find_or_create_by(user_id: user.id,
                                      repository_provider: 'github')

      VCR.use_cassette 'repos_with_4_pages' do
        visit project_wizard_path(id: :choose_repo)
        wait_for_requests_to_finish
      end
    end

    after do
      GithubRepositoryManager.send(:remove_const, :REPOSITORIES_PER_PAGE)
      GithubRepositoryManager.const_set(:REPOSITORIES_PER_PAGE, 20)
    end

    it 'displays pagination according to the number of projects', js: true do
      # 1 - 2 - 3 - 4 - next
      page.find_all('.pagination li').size.must_equal 5
      page.must_have_content 'ispyropoulos/aroma-kouzinas'
      page.must_have_content 'ispyropoulos/business_plan'
      page.must_have_content 'ispyropoulos/dockerfiles'
      page.find('.pagination li.active').text.must_equal '1'
    end

    describe 'when he is at the second page' do
      it 'displays the corrent page options', js: true do
        VCR.use_cassette 'repos_second_page' do
          click_on '2'
          wait_for_requests_to_finish
          page.must_have_content 'ispyropoulos/intl-tel-input-rails'
          page.must_have_content 'ispyropoulos/katana'
          page.must_have_content 'ispyropoulos/legendary-broccoli'
          page.all('.pagination li').size.must_equal 6
          page.find('.pagination li.active').text.must_equal '2'
        end
      end
    end

    describe 'when he is at the last page' do
      it 'displays the corrent page options', js: true do
        VCR.use_cassette 'repos_last_page' do
          click_on '4'
          wait_for_requests_to_finish
          page.find('.pagination li.active').text.must_equal '4'
          page.all('.pagination li').size.must_equal 5
        end
      end
    end
  end

  describe 'when users has projects enough for one page' do
    before do
      VCR.use_cassette 'repos_without_page' do
        visit project_wizard_path(id: :choose_repo)
      end
    end

    it 'does not display any pagination', js: true do
      page.all('.pagination').must_be :empty?
    end
  end
end
