require 'test_helper'

class ProjectWizardFeatureTest < Capybara::Rails::TestCase
  let(:user) { FactoryGirl.create(:user, projects_limit: 10) }
  let(:repo_name) { 'ispyropoulos/katana' }
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
    webhook = Sawyer::Resource.new(
      Sawyer::Agent.new('api.example.com'), { id: 1 }
    )
    RepositoryManager.any_instance.stubs(:post_add_repository_setup).returns(webhook)
    language
    language2
    technology
    login_as user, scope: :user
  end

  it "creates a project with correct attributes after successful completion", js: true do
    VCR.use_cassette 'repos'  do
      visit project_wizard_path(:select_repository)
      page.must_have_content "GitHub"
      find('label', text: "GitHub").click
      page.must_have_content repo_name
      click_on repo_name
    end

    wait_for_requests_to_finish
    project = Project.last
    project.docker_image_id.must_equal DockerImage.first.id
    project.repository_provider.must_equal 'github'
    project.repository_name.must_equal 'katana'
    project.repository_owner.must_equal 'ispyropoulos'
    project.is_private.must_equal true

    # 'Configure Testributor' page
    yaml = <<-YAML
      each:
        command: 'bin/rake'
        pattern: 'test/models/*_test.rb'
    YAML

    fill_in 'testributor_yml', with: yaml
    click_on 'Next'
    wait_for_requests_to_finish
    testributor_file = project.project_files.
      where(path: ProjectFile::JOBS_YML_PATH).first
    testributor_file.wont_equal nil
    page.wont_have_content "Please upgrade your plan"

    page.must_have_selector("#waiting_for_worker", visible: true)
    wait_for_requests_to_finish # Let socketio connection be initialized
    Broadcaster.publish(
      project.redis_live_update_resource_key, { event: "worker_added" })
    click_on "Done!"
    page.must_have_content("No branches found for project #{project.repository_owner}/#{project.name}")
    page.current_path.must_equal project_path(project)
  end
end
