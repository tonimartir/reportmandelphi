# Reportman Web base image + IBM Db2 CLI driver.
# 1) Download the IBM Data Server Driver Package (linuxx64_odbc_cli.tar.gz) from
#    IBM (license required) and place it in this folder as db2-clidriver.tar.gz
# 2) docker build -f Dockerfile.db2 -t reportman-web-db2 .
ARG BASE_IMAGE=tonimartir/reportman-web:latest
FROM ${BASE_IMAGE}

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends libxml2 \
    && rm -rf /var/lib/apt/lists/*
COPY db2-clidriver.tar.gz /tmp/db2.tar.gz
RUN mkdir -p /opt/ibm \
    && tar -xzf /tmp/db2.tar.gz -C /opt/ibm \
    && rm /tmp/db2.tar.gz \
    && echo /opt/ibm/clidriver/lib > /etc/ld.so.conf.d/db2.conf \
    && ldconfig
USER reportman
