FROM alpine:3.20 AS remote-builder

ENV LANG=C.UTF-8

# NOTE: Glibc 2.35 package is broken: https://github.com/sgerrand/alpine-pkg-glibc/issues/176, so we stick to 2.34 for now
RUN ALPINE_GLIBC_BASE_URL="https://github.com/sgerrand/alpine-pkg-glibc/releases/download" && \
    ALPINE_GLIBC_PACKAGE_VERSION="2.34-r0" && \
    ALPINE_GLIBC_BASE_PACKAGE_FILENAME="glibc-$ALPINE_GLIBC_PACKAGE_VERSION.apk" && \
    ALPINE_GLIBC_BIN_PACKAGE_FILENAME="glibc-bin-$ALPINE_GLIBC_PACKAGE_VERSION.apk" && \
    ALPINE_GLIBC_I18N_PACKAGE_FILENAME="glibc-i18n-$ALPINE_GLIBC_PACKAGE_VERSION.apk" && \
    apk add --no-cache --virtual=.build-dependencies wget ca-certificates && \
    echo \
    "-----BEGIN PUBLIC KEY-----\
    MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEApZ2u1KJKUu/fW4A25y9m\
    y70AGEa/J3Wi5ibNVGNn1gT1r0VfgeWd0pUybS4UmcHdiNzxJPgoWQhV2SSW1JYu\
    tOqKZF5QSN6X937PTUpNBjUvLtTQ1ve1fp39uf/lEXPpFpOPL88LKnDBgbh7wkCp\
    m2KzLVGChf83MS0ShL6G9EQIAUxLm99VpgRjwqTQ/KfzGtpke1wqws4au0Ab4qPY\
    KXvMLSPLUp7cfulWvhmZSegr5AdhNw5KNizPqCJT8ZrGvgHypXyiFvvAH5YRtSsc\
    Zvo9GI2e2MaZyo9/lvb+LbLEJZKEQckqRj4P26gmASrZEPStwc+yqy1ShHLA0j6m\
    1QIDAQAB\
    -----END PUBLIC KEY-----" | sed 's/   */\n/g' > "/etc/apk/keys/sgerrand.rsa.pub" && \
    wget \
    "$ALPINE_GLIBC_BASE_URL/$ALPINE_GLIBC_PACKAGE_VERSION/$ALPINE_GLIBC_BASE_PACKAGE_FILENAME" \
    "$ALPINE_GLIBC_BASE_URL/$ALPINE_GLIBC_PACKAGE_VERSION/$ALPINE_GLIBC_BIN_PACKAGE_FILENAME" \
    "$ALPINE_GLIBC_BASE_URL/$ALPINE_GLIBC_PACKAGE_VERSION/$ALPINE_GLIBC_I18N_PACKAGE_FILENAME" && \
    mv /etc/nsswitch.conf /etc/nsswitch.conf.bak && \
    apk add --no-cache --force-overwrite \
    "$ALPINE_GLIBC_BASE_PACKAGE_FILENAME" \
    "$ALPINE_GLIBC_BIN_PACKAGE_FILENAME" \
    "$ALPINE_GLIBC_I18N_PACKAGE_FILENAME" && \
    \
    mv /etc/nsswitch.conf.bak /etc/nsswitch.conf && \
    rm "/etc/apk/keys/sgerrand.rsa.pub" && \
    (/usr/glibc-compat/bin/localedef --force --inputfile POSIX --charmap UTF-8 "$LANG" || true) && \
    echo "export LANG=$LANG" > /etc/profile.d/locale.sh && \
    \
    apk del glibc-i18n && \
    \
    rm "/root/.wget-hsts" && \
    apk del .build-dependencies && \
    rm \
    "$ALPINE_GLIBC_BASE_PACKAGE_FILENAME" \
    "$ALPINE_GLIBC_BIN_PACKAGE_FILENAME" \
    "$ALPINE_GLIBC_I18N_PACKAGE_FILENAME"


# Stage 1: use docker-glibc-builder build glibc.tar.gz
FROM ubuntu:22.04 AS builder
LABEL maintainer="Sasha Gerrand <github+docker-glibc-builder@sgerrand.com>"
ARG GLIBC_VERSION=2.39
ENV DEBIAN_FRONTEND=noninteractive \
    GLIBC_VERSION=${GLIBC_VERSION} \
    PREFIX_DIR=/usr/glibc-compat
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
RUN /builder

# Stage 2: use docker-alpine-abuild package apk and keys
FROM alpine:3.20 AS packager
ARG GLIBC_VERSION=2.39
ARG ALPINE_VERSION=3.20
ARG TARGETARCH
RUN apk --no-cache add alpine-sdk coreutils cmake sudo bash \
    && adduser -G abuild -g "Alpine Package Builder" -s /bin/ash -D builder \
    && echo "builder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
    && mkdir /packages \
    && chown builder:abuild /packages
COPY ./abuilder /bin/
USER builder
ENV PACKAGER="glibc@gliderlabs.com" 
RUN abuild-keygen -na && sudo cp /home/builder/.abuild/${PACKAGER}-*.rsa.pub /etc/apk/keys/
WORKDIR /home/builder/package
COPY --from=builder /glibc-bin-${GLIBC_VERSION}.tar.gz /home/builder/package/
COPY . /home/builder/package/

ENV REPODEST=/packages
RUN case "$TARGETARCH" in \
    amd64)   export TARGET_ARCH="x86_64" ;; \
    arm64)   export TARGET_ARCH="aarch64" ;; \
    *)       echo "Unsupported architecture: $TARGETARCH" && exit 1 ;; \
    esac && \
    sed -i "s/^pkgver=.*/pkgver=${GLIBC_VERSION}/" APKBUILD && \
    sed -i "s/^arch=.*$/arch=\"${TARGET_ARCH}\"/" APKBUILD && \
    abuild checksum && abuilder -r && cp /packages/builder/${TARGET_ARCH}/*.apk /tmp/

# Stage 3: apk add apk, build alpine-glibc 
FROM alpine:3.20
ARG GLIBC_VERSION=2.39
ARG TARGETARCH
ENV GLIBC_VERSION=${GLIBC_VERSION}
ENV PACKAGER="glibc@gliderlabs.com"

RUN case "$TARGETARCH" in \
    amd64)   export LD_LINUX_PATH="/lib/ld-linux-x86_64.so.2" ;; \
    arm64)   export LD_LINUX_PATH="/lib/ld-linux-aarch64.so.1" ;; \
    *)       echo "Unsupported architecture: $TARGETARCH" && exit 1 ;; \
    esac

# use the key used during the build process
COPY --from=packager /tmp/*.apk /tmp/
COPY --from=packager /home/builder/.abuild/${PACKAGER}-*.pub /etc/apk/keys/

# install glibc APK
RUN apk add --no-cache gcompat && rm -rf ${LD_LINUX_PATH} && \
    apk add --no-cache --force-overwrite /tmp/glibc-${GLIBC_VERSION}-*.apk && \
    apk add --no-cache /tmp/glibc-bin-${GLIBC_VERSION}-*.apk && \
    apk add --no-cache /tmp/glibc-i18n-${GLIBC_VERSION}-*.apk && \
    rm -rf /tmp/*.apk

CMD ["/bin/sh"]