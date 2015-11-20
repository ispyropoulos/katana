Katana::Application.redis =
  if ENV["REDIS_URL"]
    Redis.new(url: ENV["REDIS_URL"], db: "katana")
  else
    Redis.new(db: "katana")
  end
