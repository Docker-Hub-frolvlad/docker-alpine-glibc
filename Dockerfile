FROM alpine:3.4
MAINTAINER Elifarley <elifarley@gmail.com>
ENV BASE_IMAGE=alpine:3.4

# Here we install GNU libc (aka glibc) and set C.UTF-8 locale as default.
ENV \
APK_PACKAGES="ca-certificates curl" \
LANG=C.UTF-8

ADD https://github.com/elifarley/cross-installer/archive/master.tar.gz /tmp/cross-installer.tgz
ADD https://raw.githubusercontent.com/elifarley/shell-lib/master/lib/base.sh /usr/local/shell-lib/lib/base.sh
ADD https://raw.githubusercontent.com/elifarley/cross-installer/master/install.sh /tmp/cross-installer.sh
RUN sh /tmp/cross-installer.sh /usr/local && \
  xinstall update-pkg-list && \
  xinstall install-pkg && \
  xinstall install glibc && \
  xinstall save-image-info && \
  xinstall cleanup
