#!/bin/bash

set -e

echo "[INFO] Start '$(basename $0)' at '$(date -u +"%Y-%m-%dT%H:%M:%Sz")'"

##########################################################################################
echo "[INFO] Declare variables"
##########################################################################################
TIMER_START=$(date +%s)
SCRIPT_NAME="$(basename $0 | cut -d '.' -f1)"
CURRENT_DATE="$(date -u "+%Y.%m.%d")"
CURRENT_TIME="$(date -u "+%H.%M.%S")"
ACTION="build"
NAME="myos"
BASE_OS_VARIANT="xubuntu"
BASE_OS_POINT_RELEASE="20.04.6"
BASE_OS_TYPE="desktop"
BASE_OS_ARCH="amd64"
BASE_ISO_NAME="${BASE_OS_VARIANT}-${BASE_OS_POINT_RELEASE}-${BASE_OS_TYPE}-${BASE_OS_ARCH}"
BASE_ISO_PATH="../base_iso"
CUSTOM_SOURCE_PATH="../custom_files"
CUSTOM_OUTPUT_PATH="."
WORKSPACE_PATH="iso_resources/${NAME}_${BASE_OS_POINT_RELEASE}_${BASE_OS_TYPE}_${BASE_OS_ARCH}"
SNAP_CHANNEL="candidate"
CUSTOMIZE_SCRIPT_NAME="customize_os"
PREEMPT=""
QUIET=false
ENABLE_QUIET=""
ENABLE_Q=""
ENABLE_QQ=""

USAGE="\
Usage: $0 [OPTION]... [VAR VALUE]...

  Build Options:
    --help                      show script usage
        -h
    --action VALUE              script action (build, update, remove)
        -a                          default: "\"${ACTION}\""
    --name VALUE                specify name
        -n                          default: "\"${NAME}\""
    --os_var VALUE              specify base OS variant
        -var                        default: "\"${BASE_OS_VARIANT}\""
    --os_pr VALUE               specify base OS point release
        -pr                         default: "\"${BASE_OS_POINT_RELEASE}\""
    --os_type VALUE             specify os type (desktop, server)
        -type                       default: "\"${BASE_OS_TYPE}\""
    --os_arch VALUE             specify base OS architecture
        -arch                       default: "\"${BASE_OS_ARCH}\""
    --base_iso_name VALUE       specify base iso name
        -bin                        default: "\"${BASE_ISO_NAME}\""
    --base_iso_path PATH        specify path of base iso
        -bip                        default: "\"${BASE_ISO_PATH}\""
    --custom_source_path PATH   specify path of custom source files
        -csp                        default: "\"${CUSTOM_SOURCE_PATH}\""
    --custom_output_path PATH   specify path of custom output
        -cop                        default: "\"${CUSTOM_OUTPUT_PATH}\""
    --workspace_path PATH       specify path of workspace
        -wp                         default: "\"${WORKSPACE_PATH}\""
    --snap_channel VALUE        specify snap channel (beta, candidate, stable)
        -sc                         default: "\"${SNAP_CHANNEL}\""
    --preempt VALUE             specify type preempt=[none, voluntary, full]
        -p                          default: "\"${PREEMPT}\""
    --date VALUE                specify date
        -d                          default: "\"${CURRENT_DATE}\""
    --time VALUE                specify time
        -t                          default: "\"${CURRENT_TIME}\""
    --quiet                     less verbose
        -q                          default: "\"${QUIET}\""

Example: sudo ./$(basename $0) --action \"update\" --os_pr \"20.04.6\" --os_type \"desktop\" --os_arch \"amd64\"

[WARN] This only has been tested only on Xubuntu 20.04 and 22.04 variant
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
        -a|--action)
            ACTION=$2
            shift
            ;;
        -n|--name)
            NAME=$2
            shift
            ;;
        -var|--os_var)
            BASE_OS_VARIANT=$2
            shift
            ;;
        -pr|--os_pr)
            BASE_OS_POINT_RELEASE=$2
            shift
            ;;
        -type|--os_type)
            BASE_OS_TYPE=$2
            shift
            ;;
        -arch|--os_arch)
            BASE_OS_ARCH=$2
            shift
            ;;
        -bip|--base_iso_path)
            BASE_ISO_PATH=$2
            shift
            ;;
        -bin|--base_iso_name)
            BASE_ISO_NAME_NEW=$2
            shift
            ;;
        -csp|--custom_source_path)
            CUSTOM_SOURCE_PATH=$2
            shift
            ;;
        -cop|--custom_output_path)
            CUSTOM_OUTPUT_PATH=$2
            shift
            ;;
        -wp|--workspace_path)
            WORKSPACE_PATH_NEW=$2
            shift
            ;;
        -sc|--snap_channel)
            SNAP_CHANNEL=$2
            shift
            ;;
        -p|--preempt)
            PREEMPT="preempt=$2"
            shift
            ;;
        -d|--date)
            CURRENT_DATE=$2
            shift
            ;;
        -t|--time)
            CURRENT_TIME=$2
            shift
            ;;
        -q|--quiet)
            QUIET=true
            ENABLE_QUIET="--quiet"
            ENABLE_Q="-q"
            ENABLE_QQ="-qq"
            ;;
        *)
            echo "Invalid option '$1'.  Try $0 --help to see available options."
            exit 1
            ;;
    esac
    shift
done

# Check version
if [ "${BASE_OS_POINT_RELEASE:0:2}" -lt "20" ]; then 
    echo "[ERROR] Base OS version '${BASE_OS_POINT_RELEASE}' is deprecated"; 
    exit 1
fi

# rebuild these two paths that could change based on PR
if [ -z "${WORKSPACE_PATH_NEW}" ]; then
    WORKSPACE_PATH="iso_resources/${NAME}_${BASE_OS_POINT_RELEASE}_${BASE_OS_TYPE}_${BASE_OS_ARCH}"
else
    WORKSPACE_PATH=${WORKSPACE_PATH_NEW};
fi
if [ -z "${BASE_ISO_NAME_NEW}" ]; then
    BASE_ISO_NAME="${BASE_OS_VARIANT}-${BASE_OS_POINT_RELEASE}-${BASE_OS_TYPE}-${BASE_OS_ARCH}";
else
    BASE_ISO_NAME=${BASE_ISO_NAME_NEW};
fi
IN_ISO="${BASE_ISO_NAME}.iso"
IN_ISO_PATH="${BASE_ISO_PATH}/${IN_ISO}"
IN_SHA256_NAME="${BASE_ISO_NAME}-SHA256SUMS"
IN_SHA256_PATH="${BASE_ISO_PATH}/${IN_SHA256_NAME}"

# limit to alpha numeric and length of 13 chars
# iso volume name has max 32 chars
# xxxxxxxxxxxxx 2x.04.x 2023.xx.xx
NAME="$(echo ${NAME} | tr -dc '[:alnum:]\n\r' | tr '[:upper:]' '[:lower:]')"
if [ "${#NAME}" -gt 13 ]; then
    NAME_OLD="${NAME}"
    NAME=${NAME:0:13};
    echo "[WARN] Resize name from '${NAME_OLD}' to '${NAME}'";
fi

if [ "${BASE_OS_POINT_RELEASE:0:2}" -le "20" ]; then
    ISOLINUX=true
else
    ISOLINUX=false
fi


##########################################################################################
echo "[INFO] Check apt update, upgrade, autoremove, clean"
##########################################################################################
UPDATE=$(apt-get -y ${ENABLE_QQ} update)
DEBIAN_FRONTEND=noninteractive apt-get -yq --force-yes ${ENABLE_QQ} upgrade
DEBIAN_FRONTEND=noninteractive apt-get -y ${ENABLE_QQ} autoremove
DEBIAN_FRONTEND=noninteractive apt-get -y ${ENABLE_QQ} autoclean
DEBIAN_FRONTEND=noninteractive apt-get -y ${ENABLE_QQ} clean


##########################################################################################
echo "[INFO] Install necessary build packages"
##########################################################################################
INSTALL_PACKAGES=(
    "curl" # download base iso
    "isolinux" # for 20.04 and below
    "squashfs-tools" # extract/make file system
    "whois" # mkpasswd
    "xorriso" # create bootable iso
)
for PACKAGE in "${INSTALL_PACKAGES[@]}"; do
    if [ -z "$(dpkg -l | grep "i  ${PACKAGE} ")" ]; then
        DEBIAN_FRONTEND=noninteractive apt-get -y ${ENABLE_QQ} install "${PACKAGE}";
        echo "[INFO] Installed '${PACKAGE}'";
    fi
done


##########################################################################################
echo "[INFO] Prepare workspace '${WORKSPACE_PATH}'"
##########################################################################################
mkdir -p "${WORKSPACE_PATH}" "${CUSTOM_SOURCE_PATH}" "${CUSTOM_OUTPUT_PATH}"
cd "${WORKSPACE_PATH}"

##############################
echo "[INFO] Check if '${IN_ISO_PATH}' exists"
##############################
if [ ! -f "${IN_ISO_PATH}" ]; then
    echo "[INFO] Download '${IN_ISO}'";
    BASE_URL="https://cdimage.ubuntu.com/${BASE_OS_VARIANT}/releases/${BASE_OS_POINT_RELEASE}/release/${IN_ISO}";
    curl --create-dirs -o "${IN_ISO_PATH}" -X GET -OL "${BASE_URL}";
    echo "[INFO] Downloaded '${IN_ISO}'";
fi

if [ ! -f "${IN_SHA256_PATH}" ]; then
    echo "[INFO] Download '${IN_SHA256_NAME}'";
    BASE_URL="https://cdimage.ubuntu.com/${BASE_OS_VARIANT}/releases/${BASE_OS_POINT_RELEASE}/release/SHA256SUMS";
    curl --create-dirs -o "${IN_SHA256_PATH}" -X GET -OL "${BASE_URL}";
    echo "[INFO] Downloaded '${IN_SHA256_NAME}'";
fi

if [ ! -f "${IN_SHA256_PATH}.gpg" ]; then
    echo "[INFO] Download '${IN_SHA256_NAME}.gpg'";
    BASE_URL="https://cdimage.ubuntu.com/${BASE_OS_VARIANT}/releases/${BASE_OS_POINT_RELEASE}/release/SHA256SUMS.gpg";
    curl --create-dirs -o "${IN_SHA256_PATH}.gpg" -X GET -OL "${BASE_URL}";
    echo "[INFO] Downloaded '${IN_SHA256_NAME}.gpg'";
fi

chmod 755 "${BASE_ISO_PATH}"

##############################
echo "[INFO] Verify SHA256SUM of '${IN_ISO_PATH}'"
##############################
ISO_SHA256=$(sha256sum "${IN_ISO_PATH}" | awk '{print$1}')
SHA256SUM=$(cat "${IN_SHA256_PATH}" | awk '{print$1}')
if [ "${ISO_SHA256}" != "${SHA256SUM}" ]; then
    echo "[ERROR] Invalid SHA256SUM of '${IN_ISO}'";
    rm -f "${IN_ISO_PATH}" "${IN_SHA256_PATH}" "${IN_SHA256_PATH}.gpg";
    echo "[INFO] Removed '${IN_ISO}', '${IN_SHA256_NAME}', and '${IN_SHA256_NAME}.gpg'";
    exit 1;
else
    echo "[INFO] Valid SHA256SUM of '${IN_ISO}'";
fi

# determine action
case "${ACTION}" in
    remove) # remove existing build
        echo "[INFO] Start '${ACTION}' on $(date -u +"%Y-%m-%dT%H:%M:%Sz")"
        cd ../
        rm -rf "${WORKSPACE_PATH}"
        echo "[INFO] Removed existing workspace '${WORKSPACE_PATH}'"
        ;;
    update) # update existing build
        echo "[INFO] Start '${ACTION}' on $(date -u +"%Y-%m-%dT%H:%M:%Sz")"
        if [ ! -d  "custom_disk" ] || [ ! -d  "custom_root" ] || [ ! -d  "source_disk" ]; then
            echo "[ERROR] Existing workspace '${WORKSPACE_PATH}' not found";
            exit 1;
        fi
        mkdir -p custom_root/custom_files
        cp -R "${CUSTOM_SOURCE_PATH}/${CUSTOMIZE_SCRIPT_NAME}.sh" custom_root/custom_files/
        echo "[INFO] Update workspace '${WORKSPACE_PATH}'"
        ;;
    build) # build from scratch
        echo "[INFO] Start '${ACTION}' on '$(date -u +"%Y-%m-%dT%H:%M:%Sz")'"
        rm -rf *
        # extract base iso content
        mkdir -p source_disk custom_disk
        mount -o loop "${IN_ISO_PATH}" source_disk
        rsync --exclude=/casper/filesystem.squashfs -a source_disk/ custom_disk

        # extract squash filesystem
        # NOTE: squash/unsquash works in parallels; more cores is faster! Recommend 8+
        unsquashfs -n source_disk/casper/filesystem.squashfs
        mv squashfs-root custom_root
        umount -lf source_disk

        # copy external files (should download from S3)
        mkdir -p custom_root/custom_files
        cp -R ${CUSTOM_SOURCE_PATH}/* custom_root/custom_files/
        echo "[INFO] Build workspace '${WORKSPACE_PATH}'"
        ;;
    *)  # default
        echo "[ERROR] '--action ${ACTION}' is not implemented"
        exit 1
        ;;
esac


##########################################################################################
echo "[INFO] Customize ${NAME} OS"
##########################################################################################
##############################
echo "[INFO] Bind host to chroot"
##############################
# might need to resolve host when NAT
# cp /etc/hosts custom_root/etc/
mount -o bind /run/ custom_root/run
mount --bind /dev/ custom_root/dev

##############################
echo "[INFO] Execute inside chroot"
##############################
cat <<EOF | chroot custom_root # /bin/bash
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devpts none /dev/pts

export HOME=/root
export LC_ALL=C
dbus-uuidgen > /var/lib/dbus/machine-id
dpkg-divert --local --rename --add /sbin/initctl
ln -s /bin/true /sbin/initctl

# run custom script
cd custom_files/
chmod +x ${CUSTOMIZE_SCRIPT_NAME}.sh
mkdir -p /var/log/customization
./${CUSTOMIZE_SCRIPT_NAME}.sh \
    --name ${NAME} \
    --date ${CURRENT_DATE} \
    --snap_channel ${SNAP_CHANNEL} \
    --preempt ${PREEMPT} \
    ${ENABLE_QUIET} | tee /var/log/customization/${CUSTOMIZE_SCRIPT_NAME}.log
cd ../
rm -rf custom_files

rm -rf /tmp/* ~/.bash_history
rm /var/lib/dbus/machine-id
rm /sbin/initctl
dpkg-divert --rename --remove /sbin/initctl

# umount in-chroot bindings
umount -l /proc
umount /sys
umount /dev/pts

history -c
EOF

##############################
echo "[INFO] Unbind chroot from host"
##############################
umount -lf custom_root/run
umount -lf custom_root/dev

##############################
echo "[INFO] Check if customization is successful"
##############################
BUILD_LOG="custom_root/var/log/customization/${CUSTOMIZE_SCRIPT_NAME}.log"
if [ -z "$(cat ${BUILD_LOG} | grep "Successful Customization")" ]; then
    echo "[ERROR] Unsucessful customization. See logs in '${BUILD_LOG}'"
    exit 1
fi


##########################################################################################
echo "[INFO] Generate 'custom_root/var/log/customization/changelog'"
##########################################################################################
touch changelog
cp changelog "custom_root/var/log/customization/"


##########################################################################################
echo "[INFO] Make ${NAME} iso"
##########################################################################################
##############################
echo "[INFO] Generate boot files"
##############################
if [ -f "custom_root/boot/vmlinuz" ]; then
    rm -f custom_disk/casper/vmlinuz
    cp -L custom_root/boot/vmlinuz custom_disk/casper/vmlinuz
    chmod 644 custom_disk/casper/vmlinuz
    echo "[INFO] Updated 'custom_disk/casper/vmlinuz'"
fi

if [ -f "custom_root/boot/initrd.img" ]; then
    rm -f custom_disk/casper/initrd
    cp -L custom_root/boot/initrd.img custom_disk/casper/initrd
    chmod 644 custom_disk/casper/initrd
    echo "[INFO] Updated 'custom_disk/casper/initrd'"
fi

##############################
FILEPATH="custom_disk/casper/filesystem.manifest"
echo "[INFO] Generate '${FILEPATH}'"
##############################
mv "custom_root/var/log/customization/filesystem.manifest" "${FILEPATH}"
chmod 444 "${FILEPATH}"

##############################
FILEPATH="custom_disk/casper/filesystem.squashfs"
echo "[INFO] Generate '${FILEPATH}'"
##############################
rm -f "${FILEPATH}"
mksquashfs custom_root "${FILEPATH}" -no-progress -comp xz

##############################
echo "[INFO] Sign '${FILEPATH}'"
##############################
rm -f ${FILEPATH}.gpg
FINGERPRINT=$(gpg --keyid-format long --verify "${IN_SHA256_NAME}.gpg" "${IN_SHA256_NAME}" 2>&1 | grep -o 'RSA key [^\n]*' | sed 's/RSA key //')
# gpg -u ${FINGERPRINT} -o ${FILEPATH}.gpg -b ${FILEPATH}

##############################
FILEPATH="custom_disk/casper/filesystem.size"
echo "[INFO] Generate '${FILEPATH}'"
##############################
chmod 666 "${FILEPATH}"
printf $(du -sx --block-size=1 custom_root | cut -f1) > "${FILEPATH}"
chmod 444 "${FILEPATH}"

##############################
echo "[INFO] Prepare build info"
##############################
# must get build info after chroot
# since apt update/upgrade could boost point release
# e.g. base iso is 22.04.1 but final iso is 22.04.3 after upgrade
CUSTOM_OS_POINT_RELEASE=$(cat custom_root/etc/os-release | grep VERSION= | tr -d -c [0-9.])
BUILD_INFO="${NAME} ${CUSTOM_OS_POINT_RELEASE} ${CURRENT_DATE}"
# remove link
rm -rf custom_disk/ubuntu

##############################
echo "[INFO] Generate disk info"
##############################
chmod 666 custom_disk/.disk/*

FILEPATH="custom_disk/.disk/info"
cat > "${FILEPATH}" <<EOL
${BUILD_INFO}
EOL
if [ "${QUIET}" = true ]; then
    cat "${FILEPATH}"
fi

FILEPATH="custom_disk/.disk/release_notes_url"
cat > "${FILEPATH}" <<EOL
# put link to wiki/git
EOL
if [ "${QUIET}" = true ]; then
    cat "${FILEPATH}"
fi

chmod 444 custom_disk/.disk/*

# add disk info
FILEPATH="custom_disk/README.diskdefines"
touch "${FILEPATH}"
cat > "${FILEPATH}" <<EOL
#define DISKNAME  ${BUILD_INFO}
#define TYPE  binary
#define TYPEbinary  1
#define ARCH  amd64
#define ARCHamd64  1
#define ARCHi386  0
#define DISKNUM  1
#define DISKNUM1  1
#define TOTALNUM  0
#define TOTALNUM0  1
EOL
chmod 444 "${FILEPATH}"
if [ "${QUIET}" = true ]; then
    cat "${FILEPATH}"
fi

##############################
FILEPATH="custom_disk/boot/grub/grub.cfg"
echo "[INFO] Generate '${FILEPATH}'"
# https://manpages.ubuntu.com/manpages/jammy/man7/casper.7.html
##############################
if [ -f "custom_disk/boot/grub/font.pf2" ]; then
cat > "${FILEPATH}" <<EOL
if loadfont /boot/grub/font.pf2 ; then
    set gfxmode=auto
    insmod efi_gop
    insmod efi_uga
    insmod gfxterm
    terminal_output gfxterm
fi
EOL
elif [ -f "custom_disk/boot/grub/fonts/unicode.pf2" ]; then
cat > "${FILEPATH}" <<EOL
loadfont unicode
EOL
else
cat > "${FILEPATH}" <<EOL
EOL
fi

cat >> "${FILEPATH}" <<EOL

set timeout=10
set menu_color_normal=white/black
set menu_color_highlight=black/light-gray

menuentry "Install ${BUILD_INFO}" {
    set gfxpayload=keep
    linux  /casper/vmlinuz file=/cdrom/preseed/${NAME}.seed boot=casper fsck.mode=skip automatic-ubiquity quiet noprompt ---
    initrd /casper/initrd
}
grub_platform
if [ "\$grub_platform" = "efi" ]; then
menuentry 'Boot from next volume' {
    exit 1
}
menuentry 'UEFI Firmware Settings' {
    fwsetup
}
fi
EOL
chmod 444 "${FILEPATH}"
if [ "${QUIET}" = true ]; then
    cat "${FILEPATH}"
fi

##############################
FILEPATH="custom_disk/boot/grub/loopback.cfg"
echo "[INFO] Generate '${FILEPATH}'"
# https://manpages.ubuntu.com/manpages/jammy/man7/casper.7.html
##############################
cat > "${FILEPATH}" <<EOL
menuentry "Install ${BUILD_INFO}" {
    set gfxpayload=keep
    linux  /casper/vmlinuz file=/cdrom/preseed/${NAME}.seed boot=casper fsck.mode=skip only-ubiquity quiet noprompt iso-scan/filename=\${iso_path} ---
    initrd /casper/initrd
}
EOL
# older release
if [ -f "custom_disk/install/mt86plus" ]; then
cat >> "${FILEPATH}" <<EOL
menuentry "Test memory" {
    linux16 /install/mt86plus
}
EOL
fi
chmod 644 "${FILEPATH}"
if [ "${QUIET}" = true ]; then
    cat "${FILEPATH}"
fi

# legacy isolinux
if [ "${ISOLINUX}" = true ]; then 
##############################
FILEPATH="custom_disk/isolinux/txt.cfg"
echo "[INFO] Generate '${FILEPATH}'"
##############################
cat > "${FILEPATH}" <<EOL
default live-install
label live-install
    menu label ^Install ${BUILD_INFO}
    kernel /casper/vmlinuz
    append file=/cdrom/preseed/${NAME}.seed initrd=/casper/initrd boot=casper fsck.mode=skip auto=true quiet noprompt ---
label memtest
    menu label Test ^memory
    kernel /install/mt86plus
label hd
    menu label ^Boot from first hard disk
    localboot 0x80
EOL
chmod 644 "${FILEPATH}"
if [ "${QUIET}" = true ]; then
    cat "${FILEPATH}"
fi

##############################
FILEPATH="custom_disk/preseed/cli.seed"
echo "[INFO] Generate '${FILEPATH}'"
##############################
cat > "${FILEPATH}" <<EOL
# Only install the standard system and language packs.
tasksel tasksel/first               multiselect
d-i pkgsel/language-pack-patterns   string
# No language support packages.
d-i pkgsel/install-language-support boolean false
d-i base-installer/kernel/altmeta   string hwe-20.04
EOL
chmod 644 "${FILEPATH}"
if [ "${QUIET}" = true ]; then
    cat "${FILEPATH}"
fi

##############################
FILEPATH="custom_disk/preseed/ltsp.seed"
echo "[INFO] Generate '${FILEPATH}'"
##############################
cat > "${FILEPATH}" <<EOL
# Build an LTSP client chroot.
d-i anna/choose_modules                     string ltsp-client-builder
d-i ltsp-client-builder/run                 boolean true
d-i ltsp-client-builder/build-client-opts   string --mirror file:///cdrom --security-mirror none --skipimage --components main,restricted,universe
# Enable extras.ubuntu.com.
d-i apt-setup/extras                        boolean true
# Install the Xubuntu desktop and LTSP server.
tasksel tasksel/first                       multiselect xubuntu-desktop
d-i pkgsel/include/install-recommends       boolean true
d-i pkgsel/include                          string ltsp-server-standalone openssh-server
# No XFCE translation packages yet.
d-i pkgsel/language-pack-patterns           string
# Build a client chroot.
d-i preseed/late_command                    string chroot /target /usr/sbin/ltsp-update-sshkeys
d-i base-installer/kernel/altmeta           string hwe-20.04
EOL
chmod 644 "${FILEPATH}"
if [ "${QUIET}" = true ]; then
    cat "${FILEPATH}"
fi
fi

##############################
FILEPATH="custom_disk/preseed/${NAME}.seed"
echo "[INFO] Generate '${FILEPATH}'"
##############################
PRESEED_FILES=$(ls custom_disk/preseed/ | grep -v "cli.seed\|ltsp.seed\|${NAME}.seed" | wc -l)
if [ "${PRESEED_FILES}" -gt "0" ]; then
    PRESEED_FILES=$(ls custom_disk/preseed/ | grep -v "cli.seed\|ltsp.seed\|${NAME}.seed")
    for PRESEED_FILE in ${PRESEED_FILES}; do
        rm -f custom_disk/preseed/${PRESEED_FILE}
    done
fi

cat > "${FILEPATH}" <<EOL
# Enable extras.ubuntu.com.
d-i apt-setup/extras                                boolean true
# Install the Xubuntu desktop.
tasksel tasksel/first                               multiselect xubuntu-desktop
# No XFCE translation packages yet.
d-i pkgsel/language-pack-patterns                   string
EOL

if [ "${ISOLINUX}" = true ]; then 
cat >> "${FILEPATH}" <<EOL
d-i base-installer/kernel/altmeta                   string hwe-20.04
EOL
fi

cat >> "${FILEPATH}" <<EOL

# package updates
d-i pkgsel/update-policy                            select none
d-i pkgsel/upgrade                                  select none

# general d-i stuff.
d-i debconf/priority                                string critical
d-i time/zone                                       string UTC
d-i clock-setup/ntp                                 boolean true

# locale, keyboard, etc.
d-i debian-installer/locale                         string en_US.utf8
d-i console-setup/ask_detect                        boolean false
d-i console-setup/layoutcode                        string us
d-i keyboard-configuration/ask_detect               boolean false
d-i keyboard-configuration/layoutcode               string us

# kernel modifications
# enforce ethX naming: net.ifnames=0 biosdevname=0
# disable ipv6: ipv6.disable=1
# disable intel sgx: nosgx
# disable tpm interrupt: tpm_tis.interrupts=0
d-i debian-installer/add-kernel-opts                string ipv6.disable=1 nosgx tpm_tis.interrupts=0 ${PREEMPT}

# typically one disk or raid per IPC, but preseed fails when 
# multiple disks are present (e.g. MMC and SSD on CL210G).
# Need to specify disk and prioritize NVMe, SATA, then MMC
d-i partman/early_command                           string \\
NVME=\$(list-devices disk | grep "/dev/nvme" | head -1); \\
SDA=\$(list-devices disk | grep "/dev/sda" | head -1); \\
if [ ! -z "\${NVME}" ]; then \\
    debconf-set partman-auto/disk "\${NVME}"; \\
elif [ ! -z "\${SDA}" ]; then \\
    debconf-set partman-auto/disk "\${SDA}"; \\
fi;

# https://wiki.ubuntu.com/Ubiquity/AdvancedPartitioningSchemes
# crypto with preseeded passphrase
d-i partman-auto/method                             string crypto
d-i partman-lvm/device_remove_lvm                   boolean true
d-i partman-lvm/device_remove_lvm_span              boolean true
d-i partman-auto/purge_lvm_from_device              boolean true
d-i partman-auto-lvm/new_vg_name                    string ${NAME}
d-i partman-auto/choose_recipe                      select atomic

# optional lines to overwrite old RAIDs
d-i partman-md/device_remove_md                     boolean true
d-i partman-md/confirm                              boolean true
d-i partman-md/confirm_nooverwrite                  boolean true

# When disk encryption is enabled, wipe the partitions beforehand.
d-i partman-auto-crypto/erase_disks                 boolean true
d-i partman-lvm/confirm                             boolean true
d-i partman-lvm/confirm_nooverwrite                 boolean true
d-i partman-auto-lvm/confirm                        boolean true
d-i partman-auto-lvm/confirm_nooverwrite            boolean true
d-i partman-partitioning/confirm_write_new_label    boolean true
d-i partman/confirm                                 boolean true
d-i partman/confirm_nooverwrite                     boolean true
d-i partman/choose_partition                        select finish
d-i partman-crypto/passphrase                       password ${NAME}
d-i partman-crypto/passphrase-again                 password ${NAME}
d-i partman-crypto/weak_passphrase                  boolean true

# Users
d-i passwd/user-fullname                            string ${NAME}
d-i passwd/username                                 string ${NAME}
d-i passwd/user-password-crypted                    password $(mkpasswd --method=SHA-512 --stdin ${NAME})
d-i passwd/user-default-groups                      string adm audio cdrom dip lpadmin sudo plugdev sambashare video
d-i passwd/root-login                               boolean true
d-i passwd/root-password-crypted                    password $(mkpasswd --method=SHA-512 --stdin ${NAME})
d-i user-setup/allow-password-weak                  boolean true

# minimum install
ubiquity ubiquity/minimal_install                   boolean false
ubiquity ubiquity/use_nonfree                       boolean false
# do not download updates
ubiquity ubiquity/download_updates                  boolean false
# automatically reboot after installation.
ubiquity ubiquity/reboot                            boolean true
# execute final commands
ubiquity ubiquity/success_command                   string \\
mount -o bind /dev /target/dev; \\
in-target /init/preseed/preseed.sh
EOL
chmod 644 "${FILEPATH}"
if [ "${QUIET}" = true ]; then
    cat "${FILEPATH}"
fi

##############################
FILEPATH="custom_disk/md5sum.txt"
echo "[INFO] Generate '${FILEPATH}'"
##############################
if [ "${QUIET}" = true ]; then
    find ./custom_disk/ -type f -print0 | xargs -0 md5sum | sort -k2 | sed 's|custom_disk/||g' | tee "${FILEPATH}";
else
    find ./custom_disk/ -type f -print0 | xargs -0 md5sum | sort -k2 | sed 's|custom_disk/||g' > "${FILEPATH}";
fi
chmod 444 "${FILEPATH}"

##############################
echo "[INFO] Extract MBR and EFI"
##############################
# PARTITIONS=$(fdisk -l ${IN_ISO_PATH})
# extract MBR
dd bs=1 count=446 if="${IN_ISO_PATH}" of=MBR.img
# extract EFI
EFI_PARTITION=$(fdisk -l ${IN_ISO_PATH} | grep EFI | tr -s ' ')
SKIP=$(echo ${EFI_PARTITION} | cut -d ' ' -f2)
COUNT=$(echo ${EFI_PARTITION} | cut -d ' ' -f4)
dd bs=512 count=${COUNT} skip=${SKIP} if="${IN_ISO_PATH}" of=EFI.img

# specify file format
OUT_ISO_NAME="${NAME}_${CUSTOM_OS_POINT_RELEASE}_${CURRENT_DATE}_${BASE_OS_TYPE}_${BASE_OS_ARCH}.iso"
OUT_MD5_NAME="${NAME}_${CUSTOM_OS_POINT_RELEASE}_${CURRENT_DATE}_${BASE_OS_TYPE}_${BASE_OS_ARCH}.md5"
OUT_ISO_PATH="${CUSTOM_OUTPUT_PATH}/${OUT_ISO_NAME}"
OUT_MD5_PATH="${CUSTOM_OUTPUT_PATH}/${OUT_MD5_NAME}"

##############################
echo "[INFO] Generate ISO artifacts"
##############################
# remove existing iso and md5
rm -f "${OUT_ISO_PATH}" "${OUT_MD5_PATH}"

# extract original config
# https://www.mankier.com/1/xorriso
if [ "${QUIET}" = true ]; then
    echo "[INFO] Base ISO '${IN_ISO_PATH}' xorriso info"
    xorriso -indev "${IN_ISO_PATH}" -report_el_torito as_mkisofs
fi

echo "[INFO] Generate '${OUT_ISO_NAME}'"
# anything 20.04 and below uses isolinux/syslinux
if [ "${ISOLINUX}" = true ]; then
    xorriso -as mkisofs -r -J \
        -b "isolinux/isolinux.bin" \
        -c "isolinux/boot.cat" \
        -no-emul-boot \
        -boot-load-size 4 \
        -isohybrid-mbr "/usr/lib/ISOLINUX/isohdpfx.bin" \
        -boot-info-table \
        -input-charset utf-8 \
        -eltorito-alt-boot \
        -e "boot/grub/efi.img" \
        -no-emul-boot \
        -isohybrid-gpt-basdat \
        -isohybrid-apm-hfsplus \
        -o "${OUT_ISO_PATH}" \
        -V "${BUILD_INFO}" \
        custom_disk
elif [ "${BASE_OS_POINT_RELEASE:0:2}" -eq "22" ]; then
    xorriso -as mkisofs -r \
        -iso-level 3 \
        -partition_offset 16 \
        --grub2-mbr "MBR.img" \
        --mbr-force-bootable \
        -append_partition 2 0xEF "EFI.img" \
        -appended_part_as_gpt \
        -c "/boot.catalog" \
        -b "/boot/grub/i386-pc/eltorito.img" \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        --grub2-boot-info \
        -eltorito-alt-boot \
        -e "--interval:appended_partition_2:all::" \
        -no-emul-boot \
        -o "${OUT_ISO_PATH}" \
        -V "${BUILD_INFO}" \
        custom_disk
else # might change with 24.04
    echo "[ERROR] Check xorriso output of '${IN_ISO_PATH}' before proceeding";
    exit 1
fi

echo "[INFO] Generate '${OUT_MD5_NAME}'"
md5sum "${OUT_ISO_PATH}" | sed "s|${CUSTOM_OUTPUT_PATH}/||" | tee "${OUT_MD5_PATH}"

# show disk boot settings
if [ "${QUIET}" = true ]; then
    echo "[INFO] ISO '${OUT_ISO_PATH}' xorriso info";
    xorriso -indev "${OUT_ISO_PATH}" -report_el_torito as_mkisofs;
fi

TIMER_END=$(date +%s)
DURATION=$((TIMER_END-TIMER_START))
HOURS=$((DURATION / 3600))
MINUTES=$(( (DURATION % 3600) / 60 ));
SECONDS=$(( (DURATION % 3600) % 60 ));
echo "[INFO] Duration of '$(basename $0)' is '${HOURS}h ${MINUTES}m ${SECONDS}s'"
echo "[INFO] End '$(basename $0)' at '$(date -u +"%Y-%m-%dT%H:%M:%Sz")'"
