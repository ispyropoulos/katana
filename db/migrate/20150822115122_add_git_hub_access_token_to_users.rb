class AddGitHubAccessTokenToUsers < ActiveRecord::Migration
  def change
    add_column :users, :encrypted_github_access_token, :string
    add_column :users, :encrypted_github_access_token_salt, :string
    add_column :users, :encrypted_github_access_token_iv, :string
  end
end
