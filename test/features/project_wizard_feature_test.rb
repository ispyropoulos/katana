require 'test_helper'

class ProjectWizardFeatureTest < Capybara::Rails::TestCase
  let(:user) { FactoryGirl.create(:user) }
  let(:repo_name) { 'ispyropoulos/katana' }
  let(:language) do
    FactoryGirl.create(:docker_image, :language, public_name: 'Ruby 2.0')
  end
  let(:language2) do
    FactoryGirl.create(:docker_image, :language, public_name: 'Ruby 2.3')
  end
  let(:technology) { FactoryGirl.create(:docker_image) }

  before do
    language
    language2
    technology
    login_as user, scope: :user
  end

  it "creates a project with correct attributes after successful completion",
    js: true do

    visit root_path
    find('aside').click_on 'Add a project'
    page.must_have_content "GitHub"
    find('label', text: "GitHub").click

    VCR.use_cassette 'repos'  do
      click_on "Next"
      page.must_have_content repo_name
    end

    VCR.use_cassette 'branches', allow_playback_repeats: true do
      click_on repo_name
      check 'aws'
      click_on 'Next'
    end

    # 'Configure Testributor' page
    yaml = <<-YAML
      each:
        command: 'bin/rake'
        pattern: 'test/models/*_test.rb'
    YAML

    fill_in 'testributor_yml', with: yaml
    click_on 'Next'

    # 'Select technologies' page
    select technology.public_name
    select language2.public_name
    VCR.use_cassette 'repo' do
      click_on 'Create project'
    end

    project = Project.last
    project.docker_image_id.must_equal language2.id
    project.technologies.must_equal [technology]
    project.tracked_branches.
      map(&:branch_name).sort.must_equal ['aws', 'master'].sort
    project.repository_provider.must_equal 'github'
    project.repository_name.must_equal 'katana'
    project.repository_owner.must_equal 'ispyropoulos'
    testributor_file = project.project_files.
      where(path: ProjectFile::JOBS_YML_PATH).first
    testributor_file.wont_equal nil
    page.wont_have_content "Please upgrade your plan"
  end
end
