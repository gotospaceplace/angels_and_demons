FROM ubuntu:24.04 AS build

ARG GODOT_VERSION=4.7.2

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates wget unzip \
    && rm -rf /var/lib/apt/lists/*

RUN wget -q "https://downloads.godotengine.org/?version=${GODOT_VERSION}&flavor=stable&slug=linux.x86_64.zip&platform=linux.64" \
    -O /tmp/godot.zip \
    && unzip /tmp/godot.zip -d /usr/local/bin/ \
    && mv /usr/local/bin/Godot_v${GODOT_VERSION}-stable_linux.x86_64 /usr/local/bin/godot \
    && chmod +x /usr/local/bin/godot \
    && rm /tmp/godot.zip

RUN wget -q "https://downloads.godotengine.org/?version=${GODOT_VERSION}&flavor=stable&slug=export_templates.tpz&platform=templates" \
    -O /tmp/templates.tpz \
    && mkdir -p /root/.local/share/godot/export_templates/${GODOT_VERSION}.stable \
    && unzip /tmp/templates.tpz -d /tmp/tpl \
    && cp /tmp/tpl/templates/* /root/.local/share/godot/export_templates/${GODOT_VERSION}.stable/ \
    && rm -rf /tmp/templates.tpz /tmp/tpl

WORKDIR /build
COPY . .

RUN godot --headless --import 2>&1 \
    && mkdir -p /build/output \
    && godot --headless --export-release "Linux Server" /build/output/angels_and_demons_server.x86_64

FROM ubuntu:24.04

RUN useradd -m -s /bin/bash gameserver

WORKDIR /opt/angels-and-demons

COPY --from=build /build/output/angels_and_demons_server.x86_64 ./

RUN mkdir -p config logs && chown -R gameserver:gameserver /opt/angels-and-demons

USER gameserver
EXPOSE 27050/udp

ENTRYPOINT ["./angels_and_demons_server.x86_64", "--headless"]
