FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    git \
    build-essential \
    cmake \
    make \
    gcc \
    g++ \
    zlib1g-dev \
    libmariadb-dev \
    libmariadb-dev-compat \
    mariadb-client \
    dos2unix \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt
RUN git clone https://github.com/rathena/rathena.git /rathena

WORKDIR /rathena
RUN chmod +x configure && \
    dos2unix configure && \
    ./configure && \
    make clean && \
    make -j2 server

COPY entrypoint.sh /entrypoint.sh
RUN dos2unix /entrypoint.sh && chmod +x /entrypoint.sh

CMD ["/bin/bash", "/entrypoint.sh"]