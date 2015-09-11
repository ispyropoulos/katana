class CreateOrganizationRoles < ActiveRecord::Migration
  def change
    create_table :organization_roles do |t|
      t.string :name, null: false, default: ''
    end

    create_table :organization_user_roles do |t|
      t.belongs_to :organization, null: false, index: true
      t.belongs_to :user, null: false, index: true
      t.belongs_to :organization_role, index: true

      t.timestamps
    end
  end
end
