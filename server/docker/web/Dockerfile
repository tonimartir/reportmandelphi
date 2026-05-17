FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive
ARG REPWEBEXE_SOURCE=server/docker/web/artifacts/linux64/repwebexe
ARG DBXDRIVERS_SOURCE=repman/dbxdrivers.ini

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        libicu70 \
        libunwind8 \
        libcurl4 \
        libssl3 \
        unixodbc \
        tzdata \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --home-dir /var/lib/reportman --shell /bin/bash reportman \
    && mkdir -p /opt/reportman /usr/local/etc /var/log/reportman \
    && chown -R reportman:reportman /opt/reportman /var/lib/reportman /var/log/reportman

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