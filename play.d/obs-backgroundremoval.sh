#!/bin/sh

PKGNAME=obs-backgroundremoval
SUPPORTEDARCHES="x86_64"
VERSION="$2"
DESCRIPTION="A plugin for OBS Studio that allows you to replace the background in portrait images and video, as well as enhance low-light scenes"
URL="https://github.com/occ-ai/obs-backgroundremoval"

. $(dirname $0)/common.sh

PKGURL=$(eget --list --latest https://github.com/occ-ai/obs-backgroundremoval/releases "obs-backgroundremoval-*-linux-gnu.deb")

install_pack_pkgurl
