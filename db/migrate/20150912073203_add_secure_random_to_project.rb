class AddSecureRandomToProject < ActiveRecord::Migration
  def change
    add_column :projects, :secure_random, :string
  end
end
