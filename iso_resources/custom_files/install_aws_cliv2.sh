#!/bin/bash

set -e

##############################
echo "[INFO] Install/update AWS-CLI v2"
##############################

QUIET=false
ENABLE_QQ=""
VERSION="LATEST"

USAGE="\
Usage: $0 [OPTION]... [VAR VALUE]...

    Options:
    --help                  show script usage
        -h
    --version               specify version
        -v                      default: "\"${VERSION}\""
    --quiet                 less verbose
        -q                      default: "\"${QUIET}\""

Example: sudo ./$(basename $0) --version \"2.13.4\" -q
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
        -q|--quiet)
            QUIET=true
            ENABLE_QQ="-qq"
            ;;
        -v|--version)
            VERSION=$2
            shift
            ;;
        *)
            echo "Invalid option '$1'.  Try $0 --help to see available options."
            exit 1
            ;;
    esac
    shift
done

if [ -d "/usr/local/aws-cli/v2/current" ]; then
    CURRENT_VERSION=$(aws --version | cut -d' ' -f1 | cut -d '/' -f2);
fi

if [ "${VERSION}" = "LATEST" ]; then
    LATEST_VERSION=$(curl -s "https://raw.githubusercontent.com/aws/aws-cli/v2/CHANGELOG.rst" | sed -n '5p');
    URL="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip";
    FILENAME="awscli-exe-linux-x86_64.zip";
else
    LATEST_VERSION=${VERSION};
    URL="https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${VERSION}.zip";
    FILENAME="awscli-exe-linux-x86_64-${VERSION}.zip";
fi

if [[ "${LATEST_VERSION}" != *"${CURRENT_VERSION}"* ]] || [ -z "${CURRENT_VERSION}" ]; then
    curl -X GET -L ${URL} -o ${FILENAME} && unzip ${ENABLE_QQ} -o ${FILENAME};
    if [ -d "/usr/local/aws-cli/v2/current" ]; then
        UPDATE_AWSCLI="--update";
    fi
    ./aws/install ${UPDATE_AWSCLI};
    rm -rf ${FILENAME};

    NEW_VERSION=$(aws --version | cut -d' ' -f1 | cut -d '/' -f2);
    if [ -z "${CURRENT_VERSION}" ]; then
        echo "[INFO] Installed AWS-CLI version '${NEW_VERSION}'";
    else
        echo "[INFO] Updated AWS-CLI version '${CURRENT_VERSION}' with '${NEW_VERSION}'";
    fi
else
    echo "[INFO] AWS-CLI is already up to date with version '${CURRENT_VERSION}'";
fi