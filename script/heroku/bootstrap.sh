#!/usr/bin/env sh

# Ιnstall Heroku Toolbelt (Heroku CLI)
curl -s https://s3.amazonaws.com/assets.heroku.com/heroku-client/heroku-client.tgz | tar xz
PATH="heroku-client/bin:$PATH"

# Heroku CLI automatically gets credentials from the environment variable
# `HEROKU_API_KEY`. Make sure they are always set or script will hang, waiting
# for user authentication.

# Install AWS CLI
#curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip"
#unzip awscli-bundle.zip
#./awscli-bundle/install -b ~/bin/aws

# AWS CLI automatically gets credentials from the environment variables
# `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`. Make sure they are always set
# or script will hang, waiting for user authentication.

#pr_number=`echo $HEROKU_APP_NAME | cut -d '-' -f4`

# Create a CNAME record for the Heroku Review App in Amazon Route 53 service,
# for the 'pullrequest.reviews' domain, which is managed by Amazon Route 53.
#aws route53 change-resource-record-sets --cli-input-json '{"HostedZoneId":"Z26GYZ8TE4TBNT","ChangeBatch":{"Comment":"Create a CNAME record for the Heroku Review App #'"$pr_number"'","Changes":[{"Action":"CREATE","ResourceRecordSet":{"Name":"'"$pr_number"'.pullrequest.reviews","Type":"CNAME","TTL":300,"ResourceRecords":[{"Value":"'"$HEROKU_APP_NAME"'.herokuapp.com"}]}}]}}'

# Strategy 1 - Fork production db and attach to the Review App as new db add-on
# (Warning: The Heroku API user needs to have sufficient permissions for this)

#production_app='incrediblue-production-eu'
#production_db_path=`heroku config --app ${production_app} | grep --color=never "HEROKU_POSTGRESQL_*" | awk -F"postgres://" '{print $2}'`
#production_db_url="postgres://${production_db_path}"

# Forks can be created faster using the --fast flag, however they will be up to 30 hours out-of-date.
#heroku addons:create heroku-postgresql:standard-0 --app $HEROKU_APP_NAME --fork ${production_db_url} --fast

# Strategy 2 - Restore a production db backup onto the Review App db
#script/reset_staging_db.sh $HEROKU_APP_NAME

# Strategy 3 - Load db schema from production
script/load_production_schema.sh

# Run migrations
# The Review App is automatically restarted at the end of its spawn process
bundle exec rake db:migrate

# Add a Custom Domain to the Heroku Review App (the CNAME we created previously)
#heroku domains:add "${pr_number}.pullrequest.reviews" --app $HEROKU_APP_NAME
