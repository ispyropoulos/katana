class AddBitbucketAccessTokenToUsers < ActiveRecord::Migration
  def change
    add_column :users, :encrypted_bitbucket_access_token, :string
    add_column :users, :encrypted_bitbucket_access_token_salt, :string
    add_column :users, :encrypted_bitbucket_access_token_iv, :string
    add_column :users, :encrypted_bitbucket_access_token_secret, :string
    add_column :users, :encrypted_bitbucket_access_token_secret_salt, :string
    add_column :users, :encrypted_bitbucket_access_token_secret_iv, :string
  end
end
