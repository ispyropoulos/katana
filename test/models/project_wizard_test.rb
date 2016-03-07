require 'test_helper'

class ProjectWizardTest < ActiveSupport::TestCase
  describe "validations" do
    subject { FactoryGirl.create(:project_wizard) }

    let(:postgres_9_3) do
      FactoryGirl.create(:docker_image,
                         standardized_name: "postgres", version: "9.3")
    end

    let(:postgres_9_4) do
      FactoryGirl.create(:docker_image,
                         standardized_name: "postgres", version: "9.4")
    end

    it "validates uniqueness of technology standardized names" do
      ->{ subject.technologies = [postgres_9_3, postgres_9_4] }.
        must_raise(ActiveRecord::RecordInvalid)
    end
  end

  describe "step_to_show" do
    subject { ProjectWizard.new }

    it "returns :choose_provider if repository_provider is blank" do
      subject.repository_provider.must_equal nil
      subject.step_to_show.must_equal :choose_provider
    end

    it "returns :choose_repo if repo_name is blank but repository_provider is not" do
      subject.repository_provider = "github"
      subject.repo_name.must_equal nil
      subject.step_to_show.must_equal :choose_repo
    end

    it "returns :choose_branches if repo_branches is blank but repo_name and repository_provider are not" do
      subject.repository_provider = "github"
      subject.repo_name = "katana"
      subject.branch_names.must_equal []
      subject.step_to_show.must_equal :choose_branches
    end

    it "returns :configure_testributor if testributor_yml is blank but branch_names, repo_name and repository_provider are not" do
      subject.repository_provider = "github"
      subject.repo_name = "katana"
      subject.branch_names = ['master']
      subject.testributor_yml.must_equal nil
      subject.step_to_show.must_equal :configure_testributor
    end

    it "returns :select_technologies if docker_image_id is blank but testributor_yml, branch_names, repo_name and repository_provider are not" do
      subject.repository_provider = "github"
      subject.repo_name = "katana"
      subject.branch_names = ['master']
      subject.testributor_yml = 'test'
      subject.docker_image_id.must_equal nil
      subject.step_to_show.must_equal :select_technologies
    end
  end
end
