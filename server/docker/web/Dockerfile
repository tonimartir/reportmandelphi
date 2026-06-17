FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive
ARG REPWEBEXE_SOURCE=server/docker/web/artifacts/linux64/repwebexe
ARG DBXDRIVERS_SOURCE=repman/dbxdrivers.ini

# Runtime dependencies for repwebexe plus the native client libraries for the
# database backends that FireDAC/Zeos can reach. Only free/apt clients are
# bundled. Proprietary clients (Oracle, IBM Db2, Informix, Microsoft msodbcsql)
# are not included here; add them in a derived image - see
# server/docker/web/examples/.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        tzdata \
        libicu70 \
        libunwind8 \
        libcurl4 \
        libssl3 \
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

RUN useradd --create-home --home-dir /var/lib/reportman --shell /bin/bash reportman \
    && mkdir -p /opt/reportman /usr/local/etc /var/log/reportman \
    && chown -R reportman:reportman /opt/reportman /usr/local/etc /var/lib/reportman /var/log/reportman

COPY ${REPWEBEXE_SOURCE} /opt/reportman/repwebexe
COPY ${DBXDRIVERS_SOURCE} /opt/reportman/dbxdrivers.conf
COPY server/docker/web/scripts/docker-entrypoint.sh /usr/local/bin/reportman-entrypoint.sh

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