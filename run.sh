#!/bin/bash
set -euo pipefail
set -x

declare -r PACKAGER=""
declare -r GPGKEY=""

declare -r BUILDDIR="${PWD}"
declare -r GPGDIR="${HOME}/.gnupg"
declare -r PKGDEST="/build/packages"
declare -r SRCDEST="/build/sources"
declare -r SRCPKGDEST="/build/srcpackages"
declare -r LOGDEST="/build/makepkglogs"
declare -r PKGCACHE="/build/pkgcache"

declare EXISTING="$(docker ps -a | grep manjaro-32-build | cut -d' ' -f1)"
declare -r EXISTING

if [ ! "${EXISTING}" ]; then
	docker run --rm -it \
		-e PACKAGER="${PACKAGER}" \
		-e GPGKEY="${GPGKEY}" \
		-e BRANCH="${BRANCH:-stable}" \
		-v "${BUILDDIR}":/build:rw \
		-v "${PKGDEST:-$BUILDDIR/packages}":/build/packages:rw \
		-v "${SRCDEST:-$BUILDDIR/sources}":/build/sources:rw \
		-v "${SRCPKGDEST:-$BUILDDIR/srcpackages}":/build/srcpackages:rw \
		-v "${LOGDEST:-$BUILDDIR/makepkglogs}":/build/makepkglogs:rw \
		-v "${PKGCACHE:-$BUILDDIR/pkgcache}":/pkgcache:rw \
		-v "${GPGDIR:=$BUILDDIR/gpg}":/gpg:ro \
		jonathonf/manjaro-32-build
else
	docker start "${EXISTING}"
	docker attach "${EXISTING}"
fi
