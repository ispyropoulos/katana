require 'test_helper'

class SettingsControllerTest < ActionController::TestCase
  let(:project) { FactoryGirl.create(:project) }
  let(:member) do
    project.members << (user = FactoryGirl.create(:user))
    user
  end
  let(:user) { FactoryGirl.create(:user) }

  describe 'when a user is a member of the project' do
    before { sign_in member, scope: :user }

    it 'allows GET#notifications' do
      get :notifications, params: { project_id: project }
    end

    it 'allows GET#worker_setup' do
      get :worker_setup, params: { project_id: project }
    end

    it 'allows GET#show' do
      get :show, params: { project_id: project }
    end
  end

  describe 'when a user is NOT a member of the project' do
    before { sign_in user, scope: :user }

    it 'does NOT allow GET#notifications' do
      -> { get :notifications, params: { project_id: project } }.must_raise
        ActiveRecord::RecordNotFound
    end

    it 'does NOT allow GET#worker_setup' do
      -> { get :worker_setup, params: { project_id: project } }.must_raise
        ActiveRecord::RecordNotFound
    end

    it 'does NOT allow GET#show' do
      -> { get :show, params: { project_id: project } }.must_raise
        ActiveRecord::RecordNotFound
    end
  end
end
