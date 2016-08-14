[![Docker Stars](https://img.shields.io/docker/stars/frolvlad/alpine-glibc.svg?style=flat-square)](https://hub.docker.com/r/frolvlad/alpine-glibc/)
[![Docker Pulls](https://img.shields.io/docker/pulls/frolvlad/alpine-glibc.svg?style=flat-square)](https://hub.docker.com/r/frolvlad/alpine-glibc/)


Alpine GNU C library (glibc) Docker image
=========================================

This image is based on Alpine Linux image, which is only a 5MB image, and contains glibc to enable
proprietary projects compiled against glibc (e.g. OracleJDK, Anaconda) work on Alpine.

This image includes some quirks to make [glibc](https://www.gnu.org/software/libc/) work side by
side with musl libc (default in Apline Linux). glibc packages for Alpine Linux are prepared by
[Andy Shinn](https://github.com/andyshinn) and the releases are published in
[andyshinn/alpine-pkg-glibc](https://github.com/andyshinn/alpine-pkg-glibc) github repo.

Total size of this image is only:

[![](https://images.microbadger.com/badges/image/frolvlad/alpine-glibc.svg)](http://microbadger.com/images/frolvlad/alpine-glibc "Get your own image badge on microbadger.com")

Usage Example
-------------

This image is intended to be a base image for your projects, so you may use it like this:

```Dockerfile
FROM frolvlad/alpine-glibc

COPY ./my_app /usr/local/bin/my_app
```

```sh
$ docker build -t my_app .
```

There are already several images using this image, so you can refer to them as usage examples:

* [`frolvlad/alpine-oraclejdk8`](https://hub.docker.com/r/frolvlad/alpine-oraclejdk8/) ([github](https://github.com/frol/docker-alpine-oraclejdk8))
* [`frolvlad/alpine-mono`](https://hub.docker.com/r/frolvlad/alpine-mono/) ([github](https://github.com/frol/docker-alpine-mono))
