class AddSetupStatus < ActiveRecord::Migration
  def up
    sql = <<-SQL
      UPDATE test_runs SET status = status + 1;
    SQL

    ActiveRecord::Base.connection.execute(sql)
  end

  def down
    sql = <<-SQL
      UPDATE test_runs SET status = status - 1;
    SQL

    ActiveRecord::Base.connection.execute(sql)
  end
end
