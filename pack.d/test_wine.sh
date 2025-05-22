#!/bin/sh

TAR="$1"
RETURNTARNAME="$2"
VERSION="$3"

. $(dirname $0)/common.sh

PKGNAME=$PRODUCT-$VERSION.tar

mkdir -p opt/eepm-wine/$PRODUCT/prefix

erc $TAR || fatal

mv Название_архива/* opt/eepm-wine/$PRODUCT/default/

cat <<EOF > "opt/eepm-wine/$PRODUCT/run.sh"
#!/bin/sh

STATEDIR="/opt/eepm-wine/$PRODUCT"
WINDOWSDIR=windows
INFDIR="\$WINDOWSDIR/inf"
SYSREG="\$INFDIR/system.reg"
USERREG="\$INFDIR/user.reg"
PROFILES=users
WINTEMP="\$WINDOWSDIR/temp"
WINEMODE="--attach"
WINEADMIN=default
RUNFILE="\$STATEDIR/\$WINEADMIN/YandexTelemost.exe"

fatal() {
    echo "Error: \$@" >&2
    exit 1
}

prepare_admin_tasks() {
    REALUSER="\$1"
    PREFIX="\$2"
    WINEADMIN="\$3"
    SYSREG="\$4"
    USERREG="\$5"
    PROFILES="\$6"
    WINTEMP="\$7"
    INFDIR="\$8"

    {
        echo "#!/bin/sh -e"
        echo "REALUSER=\"\$REALUSER\""
        echo "PREFIX=\"\$PREFIX\""
        echo "WINEADMIN=\"\$WINEADMIN\""
        echo "SYSREG=\"\$SYSREG\""
        echo "USERREG=\"\$USERREG\""
        echo "PROFILES=\"\$PROFILES\""
        echo "WINTEMP=\"\$WINTEMP\""
        echo "INFDIR=\"\$INFDIR\""

        echo "mkdir -p \"\\\$WINEADMIN\""

        echo "# Move drive_c directory (actually root of prefix) to shared location"
        echo "mv \"\\\$PREFIX/drive_c\" \"\\\$WINEADMIN\""

        echo "# Set permissions recursively"
        echo "chmod -R 2775 \"\\\$WINEADMIN\""

        echo "# Create users and temp directories with sticky bit and permissions"
        echo "mkdir -p \"\\\$WINEADMIN/\\\$PROFILES\""
        echo "chmod a+rwxt \"\\\$WINEADMIN/\\\$PROFILES\""
        echo "mkdir -p \"\\\$WINEADMIN/\\\$WINTEMP\""
        echo "chmod a+rwxt \"\\\$WINEADMIN/\\\$WINTEMP\""

        echo "mkdir -p \"\\\$WINEADMIN/\\\$INFDIR\""

        echo "mv \"\\\$PREFIX/system.reg\" \"\\\$WINEADMIN/\\\$SYSREG\""
        echo "mv \"\\\$PREFIX/user.reg\" \"\\\$WINEADMIN/\\\$USERREG\""
        echo "chmod -R 2775 \"\\\$WINEADMIN/\\\$INFDIR\""

        echo "# Create symlinks in prefix back to shared prefix root (no drive_c subdir!)"
        echo "ln -sf \"\\\$WINEADMIN\" \"\\\$PREFIX/drive_c\""
        echo "ln -sf \"\\\$WINEADMIN/\\\$SYSREG\" \"\\\$PREFIX/system.reg\""
        echo "ln -sf \"\\\$WINEADMIN/\\\$USERREG\" \"\\\$PREFIX/user.reg\""

        echo "# Fix ownership and permissions for user's profile folder"
        echo "chown -R \"\\\$REALUSER\" \"\\\$WINEADMIN/users/\\\$REALUSER\" || true"
        echo "chmod -R 2775 \"\\\$WINEADMIN/users/\\\$REALUSER\" || true"
    } > /tmp/eepm-wine-setup.sh

    chmod +x /tmp/eepm-wine-setup.sh
    pkexec /tmp/eepm-wine-setup.sh || fatal "Failed to execute privileged setup"
    rm -f /tmp/eepm-wine-setup.sh
}

initiate_prefix() {
    echo "Initiate prefix"
    if [ -d "\$PREFIX" ]; then
        fatal "Prefix \"\$PREFIX\" already exists. Use other name or remove/rename one."
    else
        wineboot --init || fatal "Error creating prefix."
        wineserver -w
    fi
}

if [ -z "\$first_pid" ]; then
    export first_pid="\$\$"
fi
second_pid="\$\$"

if [ "\$first_pid" = "\$second_pid" ]; then
    if [ -n "\$WINEPREFIX" ]; then
        PREFIX="\$WINEPREFIX"
    else
        PREFIX=~/.wine
    fi

    [ "\$(basename "\$WINEADMIN")" = "\$WINEADMIN" ] && WINEADMIN="\$STATEDIR/\$WINEADMIN"

    if [ "\$WINEMODE" = "--attach" ]; then
        if [ -r "\$PREFIX/attached-prefix" ]; then
            echo "Prefix already attached."
            exec wine "\$RUNFILE" "\$@"
        else
            # Если общий префикс не подготовлен, то готовим его
            if [ ! -d "\$WINEADMIN" ] || [ ! -f "\$WINEADMIN/\$SYSREG" ]; then
                echo "Preparing shared Wine environment at \$WINEADMIN"

                initiate_prefix

                # Обработка user.reg — замена имени пользователя на текущего \$USER
                cp "\$PREFIX/user.reg" "\$PREFIX/user.reg.tmp" || fatal
                WINEADMUSER=\$(grep USERNAME "\$PREFIX/user.reg.tmp" | sed 's|"||g' | sed 's|.*=||')
                sed "s/\$WINEADMUSER/\$USER/g" "\$PREFIX/user.reg.tmp" > "\$PREFIX/user.reg"
                rm -f "\$PREFIX/user.reg.tmp"

                prepare_admin_tasks "\$USER" "\$PREFIX" "\$WINEADMIN" "\$SYSREG" "\$USERREG" "\$PROFILES" "\$WINTEMP" "\$INFDIR"

                echo "Shared Wine environment prepared."
            else
                initiate_prefix
            fi

            rm -rf "\$PREFIX/drive_c" || fatal

            # Проверка, чтобы не копировать user.reg на тот же файл
            SRC_USER_REG="\$(readlink -f "\$WINEADMIN/\$USERREG")"
            DST_USER_REG="\$(readlink -f "\$PREFIX/user.reg")"
            if [ "\$SRC_USER_REG" != "\$DST_USER_REG" ]; then
                cp "\$WINEADMIN/\$USERREG" "\$PREFIX/user.reg" || fatal
            else
                echo "Skipping copy of user.reg: source and destination are the same file."
            fi

            # Заменяем имя пользователя в user.reg
            WINEADMUSER=\$(grep USERNAME "\$PREFIX/user.reg" | sed 's|"||g' | sed 's|.*=||')
            sed "s/\$WINEADMUSER/\$USER/g" "\$PREFIX/user.reg" > "\$PREFIX/user.reg.new"
            mv -f "\$PREFIX/user.reg.new" "\$PREFIX/user.reg"

            # Создаем символическую ссылку drive_c → общий префикс (корень Windows)
            ln -sf "\$WINEADMIN" "\$PREFIX/drive_c"
            ln -sf "\$WINEADMIN/\$SYSREG" "\$PREFIX/system.reg"
            ln -sf "\$WINEADMIN/\$USERREG" "\$PREFIX/user.reg"

            wineboot -u &>/dev/null
            echo "Created: \$(date)" > "\$PREFIX/attached-prefix"
        fi
    fi
fi
EOF
chmod 755 opt/eepm-wine/$PRODUCT/run.sh

cp $TAR opt/eepm-wine/$PRODUCT/
erc pack $PKGNAME opt/eepm-wine

return_tar $PKGNAME
