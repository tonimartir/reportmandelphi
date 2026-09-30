#!/bin/bash
# Runs SqldbDriversTest (built for Linux, lazbuild SqldbDriversTest.lpi)
# against PostgreSQL, MariaDB and Firebird servers in Docker containers, from
# an Ubuntu 24.04 container with their client libraries (libpq5, libmariadb3,
# libfbclient2). The containers are removed at the end.
D=$(cd "$(dirname "$0")" && pwd)
NET=rpsqldbtest
PASS=rptest-2026
cleanup() {
  docker rm -f rpsqldb-pg rpsqldb-maria rpsqldb-fb >/dev/null 2>&1
  docker network rm $NET >/dev/null 2>&1
}
trap cleanup EXIT
cleanup
docker network create $NET >/dev/null || exit 1
docker run -d --name rpsqldb-pg --network $NET -e POSTGRES_USER=rptest \
  -e POSTGRES_PASSWORD=$PASS -e POSTGRES_DB=rptest postgres:17-alpine >/dev/null || exit 1
docker run -d --name rpsqldb-maria --network $NET -e MARIADB_ROOT_PASSWORD=$PASS \
  -e MARIADB_DATABASE=rptest -e MARIADB_USER=rptest -e MARIADB_PASSWORD=$PASS \
  mariadb:11 >/dev/null || exit 1
docker run -d --name rpsqldb-fb --network $NET -e FIREBIRD_ROOT_PASSWORD=$PASS \
  -e FIREBIRD_USER=rptest -e FIREBIRD_PASSWORD=$PASS -e FIREBIRD_DATABASE=rptest.fdb \
  firebirdsql/firebird:5 >/dev/null || exit 1
# The test waits for each server (up to 90 s). With -t, as heaptrc only
# writes its report (memory leaks) to a terminal in the container
docker run --rm -t --network $NET -v "$D":/test \
  -e RP_TEST_PG="rpsqldb-pg|5432|rptest|rptest|$PASS" \
  -e RP_TEST_MYSQL="rpsqldb-maria|3306|rptest|rptest|$PASS" \
  -e RP_TEST_FB="rpsqldb-fb|3050|/var/lib/firebird/data/rptest.fdb|rptest|$PASS" \
  ubuntu:24.04 bash -c "apt-get update -qq >/dev/null && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq libpq5 libmariadb3 libfbclient2 >/dev/null && \
    /test/SqldbDriversTest"
rc=$?
echo "SqldbDriversTest exit code: $rc"
exit $rc
