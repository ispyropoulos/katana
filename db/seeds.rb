# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)
user = User.create(email: 'pakallis@gmail.com',
            password: '12345678',
            password_confirmation: '12345678')
user.confirm
user = User.create(email: 'pakallis+other@gmail.com',
            password: '12345678',
            password_confirmation: '12345678')
user.confirm

test_job = TestJob.create({
  user: User.find(1), git_ref: "e3432asdtj42929i", status: 0})
test_job_file = TestJobFile.create({
  file_name: 'test/models/user_test.rb',
  status: TestStatus::PENDING,
})
test_job.test_job_files << test_job_file
test_job.save

test_job_file = TestJobFile.create({
  file_name: 'test/models/user_test.rb',
  status: TestStatus::COMPLETE,
  started_at: Time.now,
  completed_at: Time.now + 2.minutes
})
test_job.test_job_files << test_job_file
test_job.save

test_job_file = TestJobFile.create({
  file_name: 'test/models/user_test.rb',
  status: TestStatus::COMPLETE,
  test_errors: 2,
  started_at: Time.now,
  completed_at: Time.now + 1.minute
})
test_job.test_job_files << test_job_file
test_job.save

test_job_file = TestJobFile.create({
  file_name: 'test/models/user_test.rb',
  status: TestStatus::RUNNING,
  started_at: Time.now
})
test_job.test_job_files << test_job_file
test_job.save

test_job_file = TestJobFile.create({
  file_name: 'test/models/user_test.rb',
  status: TestStatus::RUNNING,
  started_at: Time.now,
})
test_job.test_job_files << test_job_file
test_job.save

OrganizationRole.find_or_create(name: 'Admin')
OrganizationRole.find_or_create(name: 'Participant')
