BitBucket.configure do |c|
  c.client_id     = ENV['BITBUCKET_CLIENT_ID']
  c.client_secret = ENV['BITBUCKET_CLIENT_SECRET']
end
