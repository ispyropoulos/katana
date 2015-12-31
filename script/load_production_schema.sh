#!/usr/bin/env sh

# Use this script to bring your local development database
# in sync with the production database.

app='testributor'
schema_file="/tmp/${RANDOM}.production-schema.dump"
data_file="/tmp/${RANDOM}.local-data.dump"
user=`whoami`

db_url=`heroku config:get DATABASE_URL --app ${app}`

echo "What is the local database that you want to process?"
read local_db

echo "What is your database user? (default: ${user})"
read local_user

local_user=${local_user:-$user}

echo ">> Dumping data from local ${local_db} to ${data_file}..."
pg_dump --data-only -h localhost -U $local_user -Fc -f ${data_file} ${local_db}

echo ">> Dumping schema from remote ${app} to ${schema_file}..."
pg_dump --schema-only -Fc --no-acl --no-owner -f ${schema_file} $db_url

echo "<< Restoring ${schema_file} into ${local_db}..."
pg_restore --clean --no-acl --no-owner -h localhost -U $local_user -d ${local_db} ${schema_file}

echo "<< Restoring ${data_file} into ${local_db}..."
pg_restore -h localhost -U $local_user -d ${local_db} ${data_file}

echo "Cleanup..."
rm ${schema_file} ${data_file}

echo "All done!"
