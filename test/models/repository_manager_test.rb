require 'test_helper'

class RepositoryManagerTest < ActiveSupport::TestCase
  let(:project) { FactoryGirl.build(:project, repository_provider: "github") }
  subject { RepositoryManager.new({project: project}) }

  describe "manager" do
    it "is initialized based on project's repository_provider" do
      subject.manager.class.name.must_equal "GithubRepositoryManager"
    end

    it "raises if repository_manager is not implemented" do
      project.repository_provider = "dummy_provider"
      ->{ RepositoryManager.new({project: project}) }.must_raise "Unknown repository provider"
    end
  end
end
