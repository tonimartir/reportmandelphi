#!/bin/bash
# Runs SqldbDriversTest (lazbuild SqldbDriversTest.lpi) on macOS against
# PostgreSQL, MySQL and Firebird servers that run in the user folder, without
# sudo and only on 127.0.0.1, with FireDAC / SQLdb and Zeos, and SQLite. The
# official macOS builds are downloaded once to $RM_TEST_DBS (~/dev/dbs):
#   PostgreSQL 16.4 (EnterpriseDB binaries), MySQL 8.0.28 (macos11),
#   Firebird 5.0.3 (the .pkg is expanded, not installed)
# Nothing of DYLD_* is set: the client library of each server goes in its
# connection (VendorLib, LibraryLocation), as an application started from
# the Finder needs. The servers are stopped at the end; their data is
# created again each time.
set -u
D=$(cd "$(dirname "$0")" && pwd)
DBS=${RM_TEST_DBS:-$HOME/dev/dbs}
PASS=rptest-2026
PG_ZIP=postgresql-16.4-1-osx-binaries.zip
PG_URL=https://get.enterprisedb.com/postgresql/$PG_ZIP
MY_TGZ=mysql-8.0.28-macos11-x86_64.tar.gz
MY_URL=https://cdn.mysql.com/archives/mysql-8.0/$MY_TGZ
FB_PKG=Firebird-5.0.3.1683-0-macos-x64.pkg
FB_URL=https://github.com/FirebirdSQL/firebird/releases/download/v5.0.3/$FB_PKG
FB=$DBS/Firebird.framework/Versions/A/Resources

mkdir -p "$DBS/dl"
cd "$DBS" || exit 1
for spec in "$PG_ZIP|$PG_URL" "$MY_TGZ|$MY_URL" "$FB_PKG|$FB_URL"; do
  name=${spec%%|*}; url=${spec#*|}
  [ -f "dl/$name" ] || curl -fL --retry 5 -o "dl/$name" "$url" || exit 1
done
if [ ! -d pgsql ]; then
  unzip -q "dl/$PG_ZIP" && xattr -cr pgsql || exit 1
fi
if [ ! -d mysql ]; then
  tar -xzf "dl/$MY_TGZ" && mv "${MY_TGZ%.tar.gz}" mysql && xattr -cr mysql || exit 1
fi
if [ ! -d Firebird.framework ]; then
  rm -rf fbpkg
  pkgutil --expand-full "dl/$FB_PKG" fbpkg && mv fbpkg/Firebird.pkg/Payload Firebird.framework || exit 1
  rm -rf fbpkg
  xattr -cr Firebird.framework
  echo "RemoteBindAddress = 127.0.0.1" >> "$FB/firebird.conf"
fi

cleanup() {
  pgsql/bin/pg_ctl -D "$DBS/pgdata" -m fast stop >/dev/null 2>&1
  mysql/bin/mysqladmin --socket=/tmp/rptest-mysql.sock -uroot shutdown >/dev/null 2>&1
  # The server process is not the one started (it forks)
  pkill -f "$FB/bin/firebird" >/dev/null 2>&1
}
trap cleanup EXIT

# PostgreSQL: password authentication (the test also tries a wrong password)
rm -rf pgdata
echo "$PASS" > pgpass.tmp
pgsql/bin/initdb -D pgdata -U rptest --auth=scram-sha-256 --pwfile=pgpass.tmp -E UTF8 \
  --locale=C > pg-init.log 2>&1 || { cat pg-init.log; exit 1; }
rm -f pgpass.tmp
pgsql/bin/pg_ctl -D pgdata -o "-p 5432 -k /tmp -c listen_addresses=localhost" -l pg.log -w start \
  > /dev/null || exit 1
PGPASSWORD=$PASS pgsql/bin/psql -q -h localhost -U rptest -d postgres -c "create database rptest" || exit 1

# MySQL
rm -rf mydata
mysql/bin/mysqld --no-defaults --initialize-insecure --basedir="$DBS/mysql" --datadir="$DBS/mydata" \
  > my-init.log 2>&1 || { cat my-init.log; exit 1; }
mysql/bin/mysqld --no-defaults --basedir="$DBS/mysql" --datadir="$DBS/mydata" --port=3306 \
  --bind-address=127.0.0.1 --socket=/tmp/rptest-mysql.sock --mysqlx=OFF > my.log 2>&1 &
for i in $(seq 1 60); do
  mysql/bin/mysqladmin --socket=/tmp/rptest-mysql.sock -uroot ping >/dev/null 2>&1 && break
  sleep 1
done
# The server may see 127.0.0.1 as localhost: both users
mysql/bin/mysql --socket=/tmp/rptest-mysql.sock -uroot -e "create database rptest character set utf8mb4;
  create user 'rptest'@'127.0.0.1' identified by '$PASS';
  create user 'rptest'@'localhost' identified by '$PASS';
  grant all on rptest.* to 'rptest'@'127.0.0.1';
  grant all on rptest.* to 'rptest'@'localhost';" || exit 1

# Firebird: the user and the database in embedded mode, then the server
rm -f rptest.fdb
export FIREBIRD=$FB
printf "create or alter user RPTEST password '%s' using plugin Srp;\ncommit;\n" "$PASS" > fbuser.sql
"$FB/bin/isql" -q -user SYSDBA "$FB/security5.fdb" -i fbuser.sql > fb-init.log 2>&1 || { cat fb-init.log; exit 1; }
echo "create database '$DBS/rptest.fdb' user 'RPTEST' default character set UTF8;" > fbdb.sql
"$FB/bin/isql" -q -user RPTEST -i fbdb.sql >> fb-init.log 2>&1 || { cat fb-init.log; exit 1; }
rm -f fbuser.sql fbdb.sql
"$FB/bin/firebird" > fb.log 2>&1 &
unset FIREBIRD

env -u DYLD_LIBRARY_PATH -u DYLD_FALLBACK_LIBRARY_PATH \
  RP_TEST_PG="localhost|5432|rptest|rptest|$PASS|$DBS/pgsql/lib/libpq.5.dylib" \
  RP_TEST_MYSQL="127.0.0.1|3306|rptest|rptest|$PASS|$DBS/mysql/lib/libmysqlclient.21.dylib" \
  RP_TEST_FB="localhost|3050|$DBS/rptest.fdb|RPTEST|$PASS|$DBS/Firebird.framework/Versions/A/Libraries/libfbclient.dylib" \
  RP_TEST_ZEOS=1 RP_TEST_SQLITE=1 \
  "$D/SqldbDriversTest"
rc=$?
echo "SqldbDriversTest exit code: $rc"
exit $rc
