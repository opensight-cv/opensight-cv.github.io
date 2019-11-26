#!/usr/bin/env bash
set -e 

# ensure that package available v4l is at least minor version 16, if not install it manually
function handle_v4l() {
    MINOR_VER="$(${1}-cache show v4l-utils | grep Version | cut -d: -f2 | cut -d- -f1 | tr -d ' ' | cut -d'.' -f2)"
    V4L_INSTALLED=$(! dpkg -l | grep -q v4l-utils; echo $?)
    if [ "$MINOR_VER" -ge "17" ]; then
        # ensure latest version
        ${1}-get install v4l-utils
        return
    else
        if [ "$V4L_INSTALLED" -eq "1" ]; then
            read -p "You already have v4l-utils installed, however OpenSight needs a newer version to operate. Uninstall the current version and upgrade? [y/N] " yn < /dev/tty
            case $yn in
                [Yy]* ) ${1}-get remove -y v4l-utils; install_v4l_from_src;;
                * ) echo "Exiting..."; exit;;
            esac
        else
            if ! v4l2-ctl >/dev/null 2>&1; then
                install_v4l_from_src
            else
                read -p "ERROR: Unknown/uncheckable version of v4l installed. Please ensure you have a version >= 1.16! (Press enter to proceed) " < /dev/tty
            fi
        fi
    fi
}

function install_v4l_from_src() {
    mkdir -p v4l-build; cd v4l-build
    curl -L -o v4l.tar.bz2 "https://linuxtv.org/downloads/v4l-utils/v4l-utils-1.16.7.tar.bz2"
    tar xvfj v4l.tar.bz2
    cd v4l-utils-*
    ./configure
    make
    # run make install, use sudo if required
    if ! make install 2>&1; then
        sudo make install
    fi
    cd ../../
    # cleanup
    rm -rf v4l-build
}

function install_deps() {
    APTCMD="apt-get"
    if ! ${APTCMD} update >/dev/null 2>&1; then
        APTCMD="sudo apt-get"
    fi
    ${APTCMD} update
    ${APTCMD} -y install \
        build-essential bzip2 git curl tar \
        python3.7 python3-dev python3.7-dev \
        python3-pip python3-venv
    APTBASE="$(echo ${APTCMD} | cut -d'-' -f1)"
    handle_v4l ${APTBASE}
}

function handle_debian() {
    # checks if system is debian or debian derived
    IS_DEBIAN="$(! grep -q ID=debian /etc/*-release; echo $?)"
    IS_DEBIAN_LIKE="$(! grep -q ID_LIKE=debian /etc/*-release; echo $?)"
    if [ "${IS_DEBIAN}" -eq 1 ]; then
        DEBIAN=1
        TERMINOLOGY="Debian"
    fi
    if [ "$IS_DEBIAN_LIKE" -eq 1 ]; then
        DEBIAN=1
        TERMINOLOGY="a Debian derivitive (eg. Ubuntu, Raspbian)"
    fi

    # check if user wants to install deps
    if [ "${DEBIAN:-0}" -eq "1" ]; then
        read -p "You seem to be running a Debian-derivitive. Would you like to automatically install the dependencies? [Y/n] " yn < /dev/tty
        case $yn in
            [Nn]* ) : ;;
            * ) install_deps;;
        esac
    else
        echo "You do not seem to be running Debian. Skipping dependency installation..."
    fi
}

function create_repo() {
    git clone https://github.com/opensight-cv/opensight
    cd opensight
    read -p "Would you like to use the stable version of OpenSight? [Y/n] " yn < /dev/tty
    case $yn in
        [Nn]* ) : ;;
        * ) git checkout stable;;
    esac
    if [[ "$(python3 -V | cut -d"." -f2)" -ge "7" ]]; then
        PYTHON="python3"
    else
        PYTHON="python3.7"
    fi
    ${PYTHON} -m venv venv
    source venv/bin/activate
    pip3 install setuptools wheel opencv-python
    pip3 install -r requirements_min.txt
    echo "venv/bin/${PYTHON} opensight.py" > run.sh
    chmod +x run.sh
    echo 'Done! Run "run.sh" in order to run OpenSight.'
}

handle_debian
create_repo
