# https://github.com/metaskills/minitest-spec-rails/issues/49
# The recommended way of using Rails::TestTask doesn't work on rails 5
namespace :test do
  Rake::TestTask.new("features" => "test:prepare") do |t|
    t.libs = ['lib', 'test']
    t.pattern = "test/features/**/*_test.rb"
    t.verbose = true
  end
end
