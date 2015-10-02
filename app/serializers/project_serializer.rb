class ProjectSerializer < ActiveModel::Serializer
  attributes :repository_name, :repository_owner, :github_access_token,
    :build_commands

  def github_access_token
    object.user.github_access_token
  end

  def build_commands
    <<-TEXT
      bundle install
      mkdir -p config
      echo '#{database_yml}' > config/database.yml

      RAILS_ENV=test rake db:reset
    TEXT
  end

  private

  def database_yml
    "test: \n"\
    "  adapter: postgresql\n"\
    "  database: testributor_test\n"\
    "  username: testributor\n"\
    "  password: testributor_password\n"\
    "  host: localhost"
  end
end