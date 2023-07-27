#!/bin/bash

set -e

##############################
echo "[INFO] Install/update amazon-ssm-agent"
##############################

VERSION="LATEST"

USAGE="\
Usage: $0 [OPTION]... [VAR VALUE]...

    Options:
    --help                  show script usage
        -h
    --version               specify version
        -v                      default: "\"${VERSION}\""

Example: sudo ./$(basename $0) --version "1.6.0-49"
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
        *)
            echo "Invalid option '$1'.  Try $0 --help to see available options."
            exit 1
            ;;
    esac
    shift
done

if [ "${VERSION}" = "LATEST" ]; then
    LATEST_VERSION=$(curl -s "https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/VERSION");
    URL="https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent.deb";
    FILENAME="amazon-ssm-agent.deb";
else
    LATEST_VERSION=${VERSION};
    URL="https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/${VERSION}/debian_amd64/amazon-ssm-agent.deb";
    FILENAME="amazon-ssm-agent.deb";
fi

CURRENT_VERSION=$(dpkg -l | grep "i  amazon-ssm-agent" | awk '{print$3}' | cut -d '-' -f1)

if [[ "${LATEST_VERSION}" != *"${CURRENT_VERSION}"* ]] || [ -z "${CURRENT_VERSION}" ]; then
    curl -X GET -L ${URL} -o ${FILENAME} && dpkg -i ${FILENAME} && rm ${FILENAME};
    NEW_VERSION=$(dpkg -l | grep "i  amazon-ssm-agent " | awk '{print$3}' | cut -d '-' -f1);
    if [ -z "${CURRENT_VERSION}" ]; then
        echo "[INFO] Installed amazon-ssm-agent version '${NEW_VERSION}'";
    else
        echo "[INFO] Updated amazon-ssm-agent version '${CURRENT_VERSION}' with '${NEW_VERSION}'";
    fi
else
    echo "[INFO] amazon-ssm-agent is already up to date with version '${CURRENT_VERSION}'";
fi