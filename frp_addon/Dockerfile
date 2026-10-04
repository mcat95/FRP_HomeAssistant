ARG BUILD_FROM
FROM $BUILD_FROM

ARG BUILD_ARCH
ENV FRP_VERSION=0.71.0

RUN apk add --no-cache curl

# Map the Supervisor's BUILD_ARCH to frp's release asset arch naming,
# then download and extract frpc for that arch.
RUN set -eu; \
    case "${BUILD_ARCH}" in \
        amd64)   FRP_ARCH="amd64" ;; \
        aarch64) FRP_ARCH="arm64" ;; \
        armv7)   FRP_ARCH="arm" ;; \
        armhf)   FRP_ARCH="arm" ;; \
        i386)    FRP_ARCH="386" ;; \
        *) echo "Unsupported BUILD_ARCH: ${BUILD_ARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_${FRP_ARCH}.tar.gz" \
        | tar -xz -C /tmp; \
    mv "/tmp/frp_${FRP_VERSION}_linux_${FRP_ARCH}/frpc" /usr/local/bin/frpc; \
    rm -rf "/tmp/frp_${FRP_VERSION}_linux_${FRP_ARCH}"; \
    chmod +x /usr/local/bin/frpc

# Copy data for add-on
COPY run.sh /
RUN chmod a+x /run.sh

CMD [ "/run.sh" ]
