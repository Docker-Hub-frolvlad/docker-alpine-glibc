#!/usr/bin/env bash

set -exo pipefail

main() {
	declare version="${1:-$GLIBC_VERSION}" prefix="${2:-$PREFIX_DIR}"

	: "${version:?}" "${prefix:?}"

	{
		wget -qO- "https://ftpmirror.gnu.org/libc/glibc-$version.tar.gz" |
			tar zxf -
		mkdir -p /glibc-build && cd /glibc-build
		"/glibc-$version/configure" \
			--prefix="$prefix" \
			--libdir="$prefix/lib" \
			--libexecdir="$prefix/lib" \
			--enable-multi-arch \
			--enable-stack-protector=strong
		make --jobs=4 && make install
		tar --dereference --hard-dereference -zcf "/glibc-bin.tar.gz" "$prefix"
	} >&2
}

main "$@"
