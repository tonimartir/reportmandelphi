#!/bin/sh
# Creates the PostgreSQL sample database of the examples: the user rpsample
# (password rpsample) and its database rpsample with the tables and the data
# of sampledb.sql. It can run again: it reloads the data.
#
# It connects as an administrator with psql and the usual PostgreSQL
# variables (PGHOST, PGPORT, PGUSER, PGPASSWORD). Homebrew and Postgres.app
# make the user of the session an administrator, so nothing has to be set
# there; with the EnterpriseDB installer, PGUSER=postgres and its password.
# Another psql: PSQL=/path/to/psql ./createdb.sh
set -e
D=$(cd "$(dirname "$0")" && pwd)
PSQL=${PSQL:-psql}

"$PSQL" -v ON_ERROR_STOP=1 -q -d postgres <<'EOF'
do $$
begin
  if not exists (select from pg_roles where rolname = 'rpsample') then
    create role rpsample login password 'rpsample';
  end if;
end
$$;
EOF
if [ "$("$PSQL" -tA -d postgres -c "select 1 from pg_database where datname = 'rpsample'")" != 1 ]; then
  "$PSQL" -v ON_ERROR_STOP=1 -q -d postgres \
    -c "create database rpsample owner rpsample encoding 'UTF8' template template0"
fi

# The tables belong to rpsample, which connects as the reports do: TCP and
# password
PGPASSWORD=rpsample PGCLIENTENCODING=UTF8 "$PSQL" -v ON_ERROR_STOP=1 -q \
  -h "${PGHOST:-localhost}" -U rpsample -d rpsample -f "$D/sampledb.sql"
echo "Database rpsample ready: $("$PSQL" -tA -d rpsample -c 'select count(*) from sales') sales"
