# Ubuntu 24.04: its HarfBuzz (8.3) has the subsetter, libharfbuzz-subset0, which
# 22.04 lacks; without it every embedded font goes whole into the PDF (one page
# of Japanese, 28 MB). repwebexe is linked against glibc 2.28 (Rocky 8 SDK), so
# it runs on any newer distribution.
FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG REPWEBEXE_SOURCE=server/docker/web/artifacts/linux64/repwebexe
ARG DBXDRIVERS_SOURCE=repman/dbxdrivers.ini

# Runtime dependencies for repwebexe (FreeType, HarfBuzz, fontconfig, fonts and
# ICU are loaded by the report engine when it renders, not at start-up: without
# them the server answers but every report fails; Liberation has the metrics of
# Arial, Times New Roman and Courier New, and Noto the scripts of the sample
# reports: Arabic, Hebrew, Devanagari, Thai, CJK) plus the native client libraries for the
# database backends that FireDAC/Zeos can reach. Only free/apt clients are
# bundled. Proprietary clients (Oracle, IBM Db2, Informix, Microsoft msodbcsql)
# are not included here; add them in a derived image - see
# server/docker/web/examples/.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        tzdata \
        libicu74 \
        libfreetype6 \
        libharfbuzz0b \
        libharfbuzz-subset0 \
        libfontconfig1 \
        fonts-dejavu-core \
        fonts-liberation \
        fonts-noto-core \
        fonts-noto-cjk \
        libunwind8 \
        libcurl4t64 \
        libssl3t64 \
        unixodbc \
        libpq5 \
        libmariadb3 \
        libfbclient2 \
        libsqlite3-0 \
        freetds-bin \
        libsybdb5 \
        tdsodbc \
        odbc-postgresql \
        odbc-mariadb \
    && rm -rf /var/lib/apt/lists/*

# FireDAC loads SQLite by its development name (libsqlite3.so), which only the
# -dev package has: the runtime library under that name too.
RUN ln -s "$(readlink -f /usr/lib/x86_64-linux-gnu/libsqlite3.so.0)" /usr/lib/x86_64-linux-gnu/libsqlite3.so

RUN useradd --create-home --home-dir /var/lib/reportman --shell /bin/bash reportman \
    && mkdir -p /opt/reportman /usr/local/etc /var/log/reportman \
    && chown -R reportman:reportman /opt/reportman /usr/local/etc /var/lib/reportman /var/log/reportman

COPY ${REPWEBEXE_SOURCE} /opt/reportman/repwebexe
COPY ${DBXDRIVERS_SOURCE} /opt/reportman/dbxdrivers.conf
COPY server/docker/web/scripts/docker-entrypoint.sh /usr/local/bin/reportman-entrypoint.sh
# The sample reports of the designers (samples/ of the repository): nine
# reports and the SQLite database they read next to them. Read only, from the
# image: a new installation gets the SAMPLES alias pointing here.
COPY samples/ /opt/reportman/samples/

RUN chmod 0755 /opt/reportman/repwebexe /usr/local/bin/reportman-entrypoint.sh

ENV HOME=/var/lib/reportman
ENV REPORTMAN_HTTP_PORT=8080
ENV REPORTMAN_BIND=0.0.0.0
ENV REPORTMAN_ETC_DIR=/usr/local/etc

WORKDIR /opt/reportman
EXPOSE 8080

VOLUME ["/usr/local/etc", "/var/lib/reportman", "/var/log/reportman"]

USER reportman

ENTRYPOINT ["/usr/local/bin/reportman-entrypoint.sh"]