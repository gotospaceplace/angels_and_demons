FROM ubuntu:22.04

ARG GODOT_VERSION=4.3-stable

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    wget \
    unzip \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash gameserver

WORKDIR /opt/angels-and-demons
COPY . .

USER gameserver
EXPOSE 27015/udp

ENTRYPOINT ["./angels_and_demons_server"]
