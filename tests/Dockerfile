ARG REGISTRY=public.ecr.aws/docker
FROM $REGISTRY/library/postgres:13.3-alpine

RUN apk add --no-cache --virtual .build-deps build-base clang llvm11-dev && \
    cd /tmp && \
    wget -O "pg_partman-v4.5.0.tar.gz" -nv -c "https://github.com/pgpartman/pg_partman/archive/refs/tags/v4.5.0.tar.gz" && \
    tar -zxvf "pg_partman-v4.5.0.tar.gz" && \
    cd "pg_partman-4.5.0" && \
    make && \
    make NO_BGW=1 install && \
    rm -rf /tmp/* && \
    apk del .build-deps
