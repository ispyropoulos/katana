class DeviseInvitableAddToUsers < ActiveRecord::Migration
  def up
    change_table :users do |t|
      t.string     :invitation_token
      t.datetime   :invitation_created_at
      t.datetime   :invitation_accepted_at
      t.datetime   :invitation_sent_at
      t.references :invited_by, polymorphic: true
      t.index      :invitation_token, unique: true # for invitable
      t.index      :invited_by_id
    end

    change_table :organizations do |t|
      t.integer    :invitation_limit
      t.integer    :invitations_count, default: 0
      t.index      :invitations_count
    end
  end

  def down
    change_table :users do |t|
      t.remove_references :invited_by, polymorphic: true
      t.remove :invitation_accepted_at, :invitation_token, :invitation_created_at,
        :invitation_sent_at
    end

    change_table :organizations do |t|
      t.remove :invitations_count, :invitation_limit
    end
  end
end
