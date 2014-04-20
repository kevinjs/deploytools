# os - Common functions developed by YANGYUAN ( yylang1987.com )
# remember to call OS_init before anything

function os_init () {
    # OS/X (MacOSX)
    if [[ -n "`which sw_vers 2>/dev/null`" ]]; then
        # OS/X
        OS_VENDOR=`sw_vers -productName`
        OS_RELEASE=`sw_vers -productVersion`
        OS_UPDATE=${OS_RELEASE##*.}
        OS_RELEASE=${OS_RELEASE%.*}
        OS_PACKAGE=""
        if [[ "$OS_RELEASE" =~ "10.7" ]]; then
            OS_CODENAME="lion"
        elif [[ "$OS_RELEASE" =~ "10.6" ]]; then
            OS_CODENAME="snow leopard"
        elif [[ "$OS_RELEASE" =~ "10.5" ]]; then
            OS_CODENAME="leopard"
        elif [[ "$OS_RELEASE" =~ "10.4" ]]; then
            OS_CODENAME="tiger"
        elif [[ "$OS_RELEASE" =~ "10.3" ]]; then
            OS_CODENAME="panther"
        else
            OS_CODENAME=""
        fi
    elif [[ -x $(which lsb_release 2>/dev/null) ]]; then
        OS_VENDOR=$(lsb_release -i -s)
        OS_RELEASE=$(lsb_release -r -s)
        OS_UPDATE=""
        if [[ "Debian,Ubuntu" =~ $OS_VENDOR ]]; then
            OS_PACKAGE="deb"
        else
            OS_PACKAGE="rpm"
        fi
        OS_CODENAME=$(lsb_release -c -s)
    elif [[ -r /etc/redhat-release ]]; then
        # Red Hat Enterprise Linux Server release 5.5 (Tikanga)
        # CentOS release 5.5 (Final)
        # CentOS Linux release 6.0 (Final)
        # Fedora release 16 (Verne)
        OS_CODENAME=""
        for r in "Red Hat" CentOS Fedora; do
            OS_VENDOR=$r
            if [[ -n "`grep \"$r\" /etc/redhat-release`" ]]; then
                ver=`sed -e 's/^.* \(.*\) (\(.*\)).*$/\1\|\2/' /etc/redhat-release`
                OS_CODENAME=${ver#*|}
                OS_RELEASE=${ver%|*}
                OS_UPDATE=${OS_RELEASE##*.}
                OS_RELEASE=${OS_RELEASE%.*}
                break
            fi
            OS_VENDOR=""
        done
        OS_PACKAGE="rpm"
    fi

    if [[ "$OS_VENDOR" =~ (Ubuntu) ]]; then
        # 'Everyone' refers to Ubuntu releases by the code name adjective
        OS_DISTRO=$OS_CODENAME
    elif [[ "$OS_VENDOR" =~ (Fedora) ]]; then
        # For Fedora, just use 'f' and the release
        OS_DISTRO="f$OS_RELEASE"
    else
        # Catch-all for now is Vendor + Release + Update
        OS_DISTRO="$OS_VENDOR-$OS_RELEASE.$OS_UPDATE"
    fi

    export OS_VENDOR OS_RELEASE OS_UPDATE OS_PACKAGE OS_CODENAME OS_DISTRO
}

function os_echo() {
	echo  -e "\E[33;49m""\033[5m$@\033[0m"
}

function os_error() {
	echo  -e "\E[31;49m""\033[5m$@\033[0m"
	exit
}

function os_yum() {
    [[ "$OFFLINE" = "True" || -z "$@" ]] && return
    local sudo="sudo"
    [[ "$(id -u)" = "0" ]] && sudo="env"
    $sudo http_proxy=$http_proxy https_proxy=$https_proxy \
        no_proxy=$no_proxy \
        yum "$@" -y "$@"
}

function os_apt() {
    [[ "$OFFLINE" = "True" || -z "$@" ]] && return
    local sudo="sudo"
    [[ "$(id -u)" = "0" ]] && sudo="env"
    $sudo DEBIAN_FRONTEND=noninteractive \
        http_proxy=$http_proxy https_proxy=$https_proxy \
        no_proxy=$no_proxy \
        apt-get --option "Dpkg::Options::=--force-confold" --assume-yes --force-yes "$@"
}


# Distro-agnostic package installer
# install_package package [package ...]
function os_install_package() {
    if [[ -z "$OS_PACKAGE" ]]; then
        os_init
    fi

    if [[ "$OS_PACKAGE" = "deb" ]]; then
        os_apt install "$@"
    else
        os_yum install "$@"
    fi
}

# Distro-agnostic package installer
# install_package package [package ...]
function os_uninstall_package() {
    if [[ -z "$OS_PACKAGE" ]]; then
        os_init
    fi

    if [[ "$OS_PACKAGE" = "deb" ]]; then
        os_apt purge "$@"
    else
        os_yum remove "$@"
    fi
}


# Distro-agnostic function to tell if a package is installed
# is_package_installed package [package ...]
function os_is_package_installed() {
    if [[ -z "$@" ]]; then
        return 1
    fi

    if [[ -z "$OS_PACKAGE" ]]; then
        os_init
    fi
    if [[ "$OS_PACKAGE" = "deb" ]]; then
        dpkg -l "$@" > /dev/null
        return $?
    else
        rpm --quiet -q "$@"
        return $?
    fi
}


# Service wrapper to start services
# start_service service-name
function os_start_service() {
    if [[ -z "$OS_PACKAGE" ]]; then
        os_init
    fi
    if [[ "$OS_PACKAGE" = "deb" ]]; then
        sudo /usr/sbin/service $1 start
    else
        sudo /sbin/service $1 start
    fi
}


# Service wrapper to stop services
# stop_service service-name
function os_stop_service() {
    if [[ -z "$OS_PACKAGE" ]]; then
        os_init
    fi
    if [[ "$OS_PACKAGE" = "deb" ]]; then
        sudo /usr/sbin/service $1 stop
    else
        sudo /sbin/service $1 stop
    fi
}

# Service wrapper to stop services
# stop_service service-name
function os_restart_service() {
    if [[ -z "$OS_PACKAGE" ]]; then
        os_init
    fi
    if [[ "$OS_PACKAGE" = "deb" ]]; then
        sudo /usr/sbin/service $1 restart
    else
        sudo /sbin/service $1 restart
    fi
}


