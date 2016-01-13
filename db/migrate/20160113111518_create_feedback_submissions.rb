class CreateFeedbackSubmissions < ActiveRecord::Migration
  def change
    create_table :feedback_submissions do |t|
      t.string :category
      t.text :body
      t.integer :rating
      t.references :user, index: true
    end
  end
end
