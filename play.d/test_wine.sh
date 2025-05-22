#!/bin/sh

PKGNAME=test_wine
SUPPORTEDARCHES="x86_64"
DESCRIPTION=''
URL=""

. $(dirname $0)/common.sh

warn_version_is_not_supported

VERSION="1.0.0"

# Архив должен содержать весь drive_c без вложенных папок
# ProgramData
# Program Files
# Program Files (x86)
# users
# windows
PKGURL="Сюда ссылку на префикс"

install_pack_pkgurl $VERSION
