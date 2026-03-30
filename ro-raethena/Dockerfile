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
RUN chmod +x configure athena-start install.sh || true && \
    dos2unix configure athena-start install.sh || true && \
    ./configure && \
    make clean && \
    make server

WORKDIR /rathena
CMD ["./athena-start", "start"]