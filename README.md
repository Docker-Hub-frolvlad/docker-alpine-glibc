Alpine GNU C library (glibc) Docker image
=========================================

This image is based on Alpine Linux image, which is only a 5MB image, and contains glibc to enable
proprietary projects compiled against glibc (e.g. OracleJDK, Anaconda) work on Alpine.

This image includes some quirks to make glibc work side by side with musl libc (default in Apline).

Total size of this image is only:

[![](https://badge.imagelayers.io/frolvlad/alpine-glibc:latest.svg)](https://imagelayers.io/?images=frolvlad/alpine-glibc:latest 'Get your own badge on imagelayers.io')
