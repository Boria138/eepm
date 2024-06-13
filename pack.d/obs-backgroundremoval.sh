#!/bin/sh

TAR="$1"
RETURNTARNAME="$2"
URL="$4"
VERSION=$(echo "$URL" | grep -oP '\d+\.\d+\.\d+' | head -n1)

. $(dirname $0)/common.sh

erc unpack $TAR || fatal

mkdir -p usr/lib64
mv usr/lib/x86_64-linux-gnu/obs-plugins usr/lib64/obs-plugins
rm -r usr/lib/x86_64-linux-gnu

[ -n "$VERSION" ] || fatal "Can't get package version"

PKGNAME=$PRODUCT-$VERSION

erc pack $PKGNAME.tar usr || fatal

return_tar $PKGNAME.tar
