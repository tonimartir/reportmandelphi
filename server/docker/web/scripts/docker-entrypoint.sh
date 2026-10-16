#!/usr/bin/env sh
set -eu

REPORTMAN_HTTP_PORT="${REPORTMAN_HTTP_PORT:-8080}"
REPORTMAN_BIND="${REPORTMAN_BIND:-0.0.0.0}"
REPORTMAN_ETC_DIR="${REPORTMAN_ETC_DIR:-/usr/local/etc}"
REPORTMAN_HOME="${HOME:-/var/lib/reportman}"

mkdir -p "${REPORTMAN_ETC_DIR}" "${REPORTMAN_HOME}" /var/log/reportman

if [ ! -f "${REPORTMAN_ETC_DIR}/dbxdrivers.conf" ]; then
  cp /opt/reportman/dbxdrivers.conf "${REPORTMAN_ETC_DIR}/dbxdrivers.conf"
fi

if [ ! -f "${REPORTMAN_ETC_DIR}/dbxconnections.conf" ]; then
  : > "${REPORTMAN_ETC_DIR}/dbxconnections.conf"
fi

if [ ! -f "${REPORTMAN_HOME}/.etc.reportmanserver" ]; then
  # A new installation: the sample reports of the image under the SAMPLES alias
  # (only now: an alias the administrator removes later stays removed).
  if [ -d /opt/reportman/samples ]; then
    printf '[ALIASES]\nSAMPLES=/opt/reportman/samples\n' > "${REPORTMAN_HOME}/.etc.reportmanserver"
  else
    : > "${REPORTMAN_HOME}/.etc.reportmanserver"
  fi
fi

exec /opt/reportman/repwebexe -selfhosted -port="${REPORTMAN_HTTP_PORT}" -bind="${REPORTMAN_BIND}"