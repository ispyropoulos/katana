#!/bin/bash

gem install bundler
bundle check || bundle install --deployment --path /vendor/bundle --jobs 2 --retry 2
rake db:create
rake db:reset
rails s -b 0.0.0.0 -p 3000
