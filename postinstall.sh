#!/bin/bash
export RAILS_ENV=docker
bundle install
rails db:drop
rails db:create
rails db:migrate
rm /usr/src/app/tmp/pids/server.pid
rake db:seed
exec "$@"
