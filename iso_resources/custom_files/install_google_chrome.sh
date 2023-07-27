#!/bin/bash

set -e

##########################################################################################
echo "[INFO] Install Google Chrome Stable"
##########################################################################################

QUIET=false
ENABLE_QQ=""
VERSION="LATEST"
INSTALL_VKB=true
KB_EXTENSION="pflmllfnnabikmfkkaddkoolinlfninn"

USAGE="\
Usage: $0 [OPTION]... [VAR VALUE]...

    Options:
    --help                          show script usage
        -h
    --version VALUE                 specify version
        -v                              default: "\"${VERSION}\""
    --no_virtual_keyboard           install virtual keyboard
        -nvk                            default: "\"${INSTALL_VKB}\""
    --keyboard_extension VALUE      specify keyboard extension
        -ke                             default: "\"${KB_EXTENSION}\""
    --quiet                         less verbose
        -q                              default: "\"${QUIET}\""

Example: sudo ./$(basename $0) --version \"115.0.5790.110-1\" -q
"

# parse arguments
while [ $# -ne 0 ]; do
    case "$1" in
        -*.' '.*) optarg=`echo "$1" | sed 's/[-_a-zA-Z0-9]* //'` ;;
        *) optarg= ;;
    esac
    case "$1" in
        -h|--help)
            echo "${USAGE}" 1>&2
            exit 1
            ;;
        -v|--version)
            VERSION=$2
            shift
            ;;
        -nvk|no_virtual_keyboard)
            INSTALL_VKB=false
            ;;
        -q|--quiet)
            QUIET=true
            ENABLE_QQ="-qq"
            ;;
        *)
            echo "Invalid option '$1'.  Try $0 --help to see available options."
            exit 1
            ;;
    esac
    shift
done

if [ "${VERSION}" = "LATEST" ]; then
    LATEST_VERSION=$(curl -s "https://omahaproxy.appspot.com/history" | awk -F',' '/linux,stable/{print $3; exit}');
    URL="https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb";
    FILENAME="google-chrome-stable_current_amd64.deb";
else
    LATEST_VERSION=${VERSION};
    URL="dl.google.com/linux/chrome/deb/pool/main/g/google-chrome-stable/google-chrome-stable_${VERSION}_amd64.deb";
    FILENAME="amazon-cloudwatch-agent.deb";
fi

CURRENT_VERSION=$(dpkg -l | grep "i  google-chrome-stable " | awk '{print$3}' | cut -d '-' -f1)

if [[ "${LATEST_VERSION}" != *"${CURRENT_VERSION}"* ]] || [ -z "${CURRENT_VERSION}" ]; then
    curl -X GET -L ${URL} -o ${FILENAME} && dpkg -i ${FILENAME} && rm ${FILENAME};

    NEW_VERSION=$(dpkg -l | grep "i  google-chrome-stable " | awk '{print$3}' | cut -d '-' -f1);
    if [ -z "${CURRENT_VERSION}" ]; then
        echo "[INFO] Installed google-chrome-stable version '${NEW_VERSION}'";
    else
        echo "[INFO] Updated google-chrome-stable version '${CURRENT_VERSION}' with '${NEW_VERSION}'";
    fi
else
    echo "[INFO] google-chrome-stable is already up to date with version '${CURRENT_VERSION}'";
fi


if [ "${INSTALL_VKB}" = true ]; then
    ##############################
    echo "[INFO] Install Chrome keyboard extension '${KB_EXTENSION}'";
    ##############################
    if [ -f "${KB_EXTENSION}.zip" ]; then
        rm -rf /etc/skel/${KB_EXTENSION}/;
        unzip ${ENABLE_QQ} ${KB_EXTENSION}.zip;
        mv ${KB_EXTENSION} /etc/skel/;
        rm ${KB_EXTENSION}.zip;
        chmod -R 500 /etc/skel/${KB_EXTENSION}/;
        echo "[INFO] Installed Chrome keyboard extension '${KB_EXTENSION}' to '/etc/skel/'";
    fi
fi
