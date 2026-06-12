#!/bin/sh

set -eu

psql \
  --username "$POSTGRES_USER" \
  --dbname "$POSTGRES_DB" \
  --set=ON_ERROR_STOP=1 \
  --set=astronomy_password="$ASTRONOMY_USER_PASSWORD" \
  --set=monitoring_password="$MONITORING_USER_PASSWORD" \
  --file=/opt/astronomy/init.sql
