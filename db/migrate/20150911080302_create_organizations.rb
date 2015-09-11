class CreateOrganizations < ActiveRecord::Migration
  def change
    create_table :organizations do |t|
      t.belongs_to :user, null: false, index: true
      t.string :name, null: false

      t.timestamps
    end
  end
end
