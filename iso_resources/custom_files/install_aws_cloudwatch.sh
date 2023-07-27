#!/bin/bash

set -e

##############################
echo "[INFO] Install amazon-cloudwatch-agent"
##############################

VERSION="LATEST"

USAGE="\
Usage: $0 [OPTION]... [VAR VALUE]...

    Options:
    --help                  show script usage
        -h
    --version               specify version
        -v                      default: "\"${VERSION}\""

Example: sudo ./$(basename $0) --version "1.247360.0b252689"
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
    LATEST_VERSION=$(curl -s "https://s3.amazonaws.com/amazoncloudwatch-agent/info/latest/CWAGENT_VERSION");
    URL="https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb";
    FILENAME="amazon-cloudwatch-agent.deb";
else
    LATEST_VERSION=${VERSION};
    URL="https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/${VERSION}/amazon-cloudwatch-agent.deb";
    FILENAME="amazon-cloudwatch-agent.deb";
fi

CURRENT_VERSION=$(dpkg -l | grep "amazon-cloudwatch-agent" | awk '{print$3}' | cut -d '-' -f1)

if [[ "${LATEST_VERSION}" != *"${CURRENT_VERSION}"* ]] || [ -z "${CURRENT_VERSION}" ]; then
    curl -X GET -L ${URL} -o ${FILENAME} && dpkg -i ${FILENAME} && rm ${FILENAME};
    NEW_VERSION=$(dpkg -l | grep "amazon-cloudwatch-agent" | awk '{print$3}' | cut -d '-' -f1);
    if [ -z "${CURRENT_VERSION}" ]; then
        echo "[INFO] Installed amazon-cloudwatch-agent version '${NEW_VERSION}'";
    else
        echo "[INFO] Updated amazon-cloudwatch-agent version '${CURRENT_VERSION}' with '${NEW_VERSION}'";
    fi
else
    echo "[INFO] amazon-cloudwatch-agent is already up to date with version '${CURRENT_VERSION}'";
fi
# install default config
if [ -f "install_cw_config.sh" ]; then
    chmod 700 "install_cw_config.sh";
    mv install_cw_config.sh /init/;
    echo "[INFO] Installed '/init/install_cw_config.sh'";
fi

##############################
FILEPATH="/opt/aws/amazon-cloudwatch-agent/etc/common-config.toml"
echo "[INFO] Generate '${FILEPATH}'"
##############################
cat > "${FILEPATH}" <<EOL
# This common-config is used to configure items used for both ssm and cloudwatch access


## Configuration for shared credential.
## Default credential strategy will be used if it is absent here:
##      Instance role is used for EC2 case by default.
##      AmazonCloudWatchAgent profile is used for onPremise case by default.
[credentials]
  shared_credential_profile = "default"
  shared_credential_file = "/root/.aws/credentials"


## Configuration for proxy.
## System-wide environment-variable will be read if it is absent here.
## i.e. HTTP_PROXY/http_proxy; HTTPS_PROXY/https_proxy; NO_PROXY/no_proxy
## Note: system-wide environment-variable is not accessible when using ssm run-command.
## Absent in both here and environment-variable means no proxy will be used.
# [proxy]
#    http_proxy = "{http_url}"
#    https_proxy = "{https_url}"
#    no_proxy = "{domain}"

# [ssl]
#    ca_bundle_path = "{ca_bundle_file_path}"
EOL