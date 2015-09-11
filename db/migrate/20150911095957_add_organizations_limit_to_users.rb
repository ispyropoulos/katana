class AddOrganizationsLimitToUsers < ActiveRecord::Migration
  def change
    add_column :users, :organizations_limit, :integer, null: false, default: 0
  end
end
