require 'test_helper'
require 'timeout'

class ProjectWizardFeatureTest < Capybara::Rails::TestCase
  let(:user) { FactoryGirl.create(:user, projects_limit: 10) }
  let(:repo_name) { 'testributor-github-api-test-user/agent' }
  let(:language) do
    FactoryGirl.create(:docker_image, :language, public_name: 'Ruby 2.0')
  end
  let(:language2) do
    FactoryGirl.create(:docker_image, :language, public_name: 'Ruby 2.3')
  end
  let(:technology) { FactoryGirl.create(:docker_image) }

  before do
    GithubRepositoryManager.send(:remove_const, :REPOSITORIES_PER_PAGE)
    GithubRepositoryManager.const_set(:REPOSITORIES_PER_PAGE, 20)
    RepositoryManager.any_instance.stubs(:post_add_repository_setup).
      returns({ webhook_id: 1 })
    language
    language2
    technology
    login_as user, scope: :user
  end

  after do
    GithubRepositoryManager.send(:remove_const, :REPOSITORIES_PER_PAGE)
    GithubRepositoryManager.const_set(:REPOSITORIES_PER_PAGE, 10)
  end

  it "creates a project with correct attributes after successful completion", js: true do
    VCR.use_cassette (self.class.name + "::" + self.__name__) do
      visit project_wizard_path(:select_repository)
      page.must_have_content "GITHUB"
      find('label', text: "GITHUB").click
      page.must_have_content repo_name
      click_on repo_name
      wait_for_requests_to_finish
    end

    project = Project.last
    project.docker_image_id.must_equal DockerImage.first.id
    project.repository_provider.must_equal 'github'
    project.repository_name.must_equal 'agent'
    project.repository_owner.must_equal 'testributor-github-api-test-user'
    project.is_private.must_equal false

    # 'Configure Testributor' page
    yaml = <<-YAML
      each:
        command: 'bin/rake'
        pattern: 'test/models/*_test.rb'
    YAML

    page.driver.execute_script(
      "window.code_editor.setValue(#{yaml.inspect});")
    click_on 'Next'
    testributor_file = project.project_files.
      where(path: ProjectFile::JOBS_YML_PATH).first
    testributor_file.wont_equal nil
    page.wont_have_content "Please upgrade your plan"
    page.must_have_selector("#waiting_for_worker", visible: true)
    Timeout::timeout(3) {
      loop do # wait for connection with socketio
        break if evaluate_script("window.liveUpdates.socket.id")
        sleep 0.01
      end
      loop do # wait for subscribe requrest to be made
        break if page.driver.network_traffic.detect {|r| r.url.match(/\/subscribe/) }
        sleep 0.01
      end
    }
    wait_for_requests_to_finish
    Broadcaster.publish(
      project.redis_live_update_resource_key, { event: "worker_added" })
    click_on "Done!"
    page.must_have_content("Track a branch")
    page.current_path.must_equal project_test_runs_path(project)
  end

  it 'displays the correct badges', js: true do
    VCR.use_cassette (self.class.name + "::" + self.__name__) do
      visit project_wizard_path(:select_repository)
      page.must_have_content "GITHUB"
      find('label', text: "GITHUB").click
      page.must_have_content repo_name
    end

    repositories = all('.list-group-item')
    repositories[1].find('.list-group-item-heading').text.must_equal 'testributor-github-api-test-user/agent'
    repositories[1].all('span').first.text.must_equal 'FORK'
    repositories[1].all('span')[1].text.must_equal 'PUBLIC'

    repositories[0].find('.list-group-item-heading').text.must_equal 'ispyropoulos/aroma-kouzinas'
    repositories[0].all('span').first.text.must_equal 'PRIVATE'
  end
end
