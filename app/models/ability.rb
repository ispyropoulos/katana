class Ability
  include CanCan::Ability

  attr_accessor :user, :project

  def initialize(user, project=nil)
    @user = user
    @project = project

    live_updates_permissions

    if project.present?
      test_job_permissions
      test_run_permissions
      project_permissions
      tracked_branch_permissions
      project_participation_permissions
      project_files_permissions
      worker_group_permissions
    end
  end

  private

  def worker_group_permissions
    # TODO: Check if we should be more strict here.
    if user && project.members.include?(user)
      can :update, WorkerGroup, project_id: project.id
      can :create, WorkerGroup
      can :destroy, WorkerGroup, project_id: project.id
    end
  end

  def project_participation_permissions
    # Project owners can remove all users but themselves from a project
    if user.present?
      if project.user == user
        can :manage, ProjectParticipation, project_id: project.id
        cannot :destroy, ProjectParticipation, user_id: user.id
      elsif project.members.include?(user)
        can :read, ProjectParticipation, user_id: user.id
        can :destroy, ProjectParticipation, user_id: user.id
        can :update, ProjectParticipation, user_id: user.id
      end
    end
  end

  def project_files_permissions
    if user.present? && project.user == user
      can :manage, ProjectFile, project_id: project.id
    end

    if project.members.include?(user)
      can :read, ProjectFile, project_id: project.id
      can :update, ProjectFile, project_id: project.id
      can :destroy, ProjectFile, project_id: project.id
      can :create, ProjectFile, project_id: project.id
    end
  end

  def project_permissions
    if user.present? && project.user == user
      can :manage, project
    end

    if project.members.include?(user)
      can :read_instructions, project
      can :read_docker_compose, project
      can :read_general_settings, project
      can :read, project
      can :manage_own_notification_settings, project
      can :update_worker_setup, project
    end

    if project.is_public?
      can :read, project
    end
  end

  def tracked_branch_permissions
    if project && project.members.include?(user)
      can :create, TrackedBranch
      can :destroy, TrackedBranch
      can :untrack_branch, TrackedBranch
    end
  end

  def test_run_permissions
    can :read, TestRun if project && project.is_public?
    can :manage, TestRun if project && project.members.include?(user)
  end

  def test_job_permissions
    can :manage, TestJob if project && project.members.include?(user)
  end

  def live_updates_permissions
    can :read_live_updates, TestJob do |test_job|
      project = test_job.test_run.project
      project.members.include?(user) || project.is_public?
    end

    can :read_live_updates, TestRun do |test_run|
      project = test_run.project
      project.members.include?(user) || project.is_public?
    end

    can :read_live_updates, TrackedBranch do |branch|
      project = branch.project
      project.members.include?(user) || project.is_public?
    end

    can :read_live_updates, Project do |project|
      project.members.include?(user)
    end
  end
end
