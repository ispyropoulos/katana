class AddLastUsedAtOnTokens < ActiveRecord::Migration
  def change
    add_column :oauth_access_tokens, :last_used_at, :datetime
  end
end
