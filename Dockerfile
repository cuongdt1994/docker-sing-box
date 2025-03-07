# ====== Builder Stage ======
FROM debian:bookworm-slim AS builder

ARG SING_BOX_VERSION="1.11.4"
ARG SING_BOX_URL="https://github.com/SagerNet/sing-box/releases/download/v${SING_BOX_VERSION}/"

RUN set -eux \
    && apt-get update -qyy \
    && apt-get install -qyy --no-install-recommends \
        ca-certificates wget curl jq \
    && rm -rf /var/lib/apt/lists/* /var/log/* \
    \
    # Xác định kiến trúc và tải về sing-box phù hợp
    && ARCH=$(dpkg --print-architecture) \
    && case "$ARCH" in \
            "amd64")  SING_BOX_FILENAME="sing-box-${SING_BOX_VERSION}-linux-amd64.tar.gz" ;; \
            "arm64")  SING_BOX_FILENAME="sing-box-${SING_BOX_VERSION}-linux-arm64.tar.gz" ;; \
            "armhf")  SING_BOX_FILENAME="sing-box-${SING_BOX_VERSION}-linux-armv7.tar.gz" ;; \
            *) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
       esac \
    \
    && wget -O sing-box.tar.gz "${SING_BOX_URL}${SING_BOX_FILENAME}" \
    && tar -xzvf sing-box.tar.gz \
    && mv sing-box*/sing-box /usr/local/bin/sing-box \
    && rm -rf sing-box*

# Tải về hev-socks5-tunnel
RUN ARCH=$(dpkg --print-architecture) && \
    case "$ARCH" in \
        "amd64")  HEV_TUNNEL_FILE="hev-socks5-tunnel-linux-x86_64" ;; \
        "arm64")  HEV_TUNNEL_FILE="hev-socks5-tunnel-linux-arm64" ;; \
        "armhf")  HEV_TUNNEL_FILE="hev-socks5-tunnel-linux-arm32" ;; \
        *) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
    esac && \
    \
    RELEASE_URL=$(curl -s https://api.github.com/repos/heiher/hev-socks5-tunnel/releases/latest | \
                  jq -r ".assets[] | select(.name == \"${HEV_TUNNEL_FILE}\") | .browser_download_url") && \
    curl -L "$RELEASE_URL" -o /usr/local/bin/hev-socks5-tunnel && \
    chmod +x /usr/local/bin/hev-socks5-tunnel

# ====== Runtime Stage ======
FROM debian:bookworm-slim

COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh
COPY --from=builder /usr/local/bin/sing-box /usr/local/bin/
COPY --from=builder /usr/local/bin/hev-socks5-tunnel /usr/local/bin/

RUN set -eux \
    && apt-get update -qyy \
    && apt-get install -qyy --no-install-recommends \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/* /var/log/*

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
