Katana::Application.redis =
  if ENV["REDIS_URL"]
    Redis.new(url: ENV["REDIS_URL"], db: "katana_#{Rails.env}")
  else
    Redis.new(db: "katana_#{Rails.env}")
  end

$redis = Katana::Application.redis
