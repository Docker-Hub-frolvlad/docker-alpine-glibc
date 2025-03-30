# Stage 1: use docker-glibc-builder build glibc.tar.gz
FROM ubuntu:22.04 AS builder
LABEL maintainer="Sasha Gerrand <github+docker-glibc-builder@sgerrand.com>"
RUN apt-get -q update \
    && apt-get -qy install \
    bison \
    build-essential \
    gawk \
    gettext \
    openssl \
    python3 \
    texinfo \
    wget
COPY configparams /glibc-build/configparams
COPY builder /builder
ARG GLIBC_VERSION=2.41
RUN env PREFIX_DIR=/usr/glibc-compat /builder


# Stage 2: use docker-alpine-abuild package apk and keys
FROM alpine:3.20 AS packager
RUN apk --no-cache add alpine-sdk coreutils cmake sudo \
    && adduser -G abuild -g "Alpine Package Builder" -s /bin/ash -D builder \
    && echo "builder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
    && mkdir /packages \
    && chown builder:abuild /packages
COPY ./abuilder /bin/
USER builder
ENV PACKAGER="glibc@gliderlabs.com" 
RUN abuild-keygen -na && sudo cp /home/builder/.abuild/${PACKAGER}-*.rsa.pub /etc/apk/keys/

WORKDIR /home/builder/package
COPY --from=builder /glibc-bin.tar.gz /home/builder/package/
COPY . /home/builder/package/

ARG GLIBC_VERSION=2.41
ARG TARGETARCH
RUN case "$TARGETARCH" in \
    amd64)   export TARGET_ARCH="x86_64" ;; \
    arm64)   export TARGET_ARCH="aarch64" ;; \
    *)       echo "Unsupported architecture: $TARGETARCH" && exit 1 ;; \
    esac && \
    sed -i "s/^pkgver=.*/pkgver=${GLIBC_VERSION}/" APKBUILD && \
    sed -i "s/^arch=.*$/arch=\"${TARGET_ARCH}\"/" APKBUILD && \
    abuild checksum && \
    env REPODEST=/packages abuilder -r && \
    mv /packages/builder/${TARGET_ARCH}/*.apk /tmp/


# Stage 3: apk add apk, build alpine-glibc 
FROM alpine:3.21
ARG GLIBC_VERSION=2.41
ARG TARGETARCH
RUN --mount=from=packager,src=/tmp/,dst=/tmp/ \
    --mount=from=packager,src=/etc/apk/keys,dst=/etc/apk/keys/ \
    case "$TARGETARCH" in \
    amd64)   export LD_LINUX_PATH="/lib/ld-linux-x86_64.so.2" ;; \
    arm64)   export LD_LINUX_PATH="/lib/ld-linux-aarch64.so.1" ;; \
    *)       echo "Unsupported architecture: $TARGETARCH" && exit 1 ;; \
    esac && \
    apk add --no-cache \
        /tmp/glibc-${GLIBC_VERSION}-*.apk \
        /tmp/glibc-bin-${GLIBC_VERSION}-*.apk \
        /tmp/glibc-i18n-${GLIBC_VERSION}-*.apk && \
    /usr/glibc-compat/bin/localedef --force --inputfile POSIX --charmap UTF-8 C.UTF-8 || true && \
    echo "export LANG=C.UTF-8" > /etc/profile.d/locale.sh && \
    apk del glibc-i18n
