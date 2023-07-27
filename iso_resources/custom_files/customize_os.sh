#!/bin/bash

set -e

echo "[INFO] Start '$(basename $0)' at '$(date -u +"%Y-%m-%dT%H:%M:%Sz")'"

##########################################################################################
echo "[INFO] Declare variables"
##########################################################################################
TIMER_START=$(date +%s)
SCRIPT_NAME=$(basename $0 | cut -d '.' -f1)
CURRENT_DATE="$(date -u "+%Y.%m.%d")"
CURRENT_TIME="$(date -u "+%H.%M.%S")"
NAME="myos"
BASE_OS_ARCH="amd64"
SNAP_CHANNEL="candidate"
PREEMPT=""
QUIET=false
ENABLE_QUIET=""
ENABLE_Q=""
ENABLE_QQ=""
LOG_PATH="/var/log/customization"
mkdir -p "${LOG_PATH}" "/init/preseed" "/var/log/init"

USAGE="\
Usage: $0 [OPTION]... [VAR VALUE]...

    Options:
    --help                  show script usage
        -h
    --name VALUE            specify name
        -n                      default: "\"${NAME}\""
    --os_arch VALUE         specify base OS architecture
        -arch                   default: "\"${BASE_OS_ARCH}\""
    --snap_channel VALUE    specify snap channel (beta, candidate, stable)
        -sc                     default: "\"${SNAP_CHANNEL}\""
    --preempt VALUE         specify type preempt=[none, voluntary, full]
        -p                      default: "\"${PREEMPT}\""
    --date VALUE            specify date
        -d                      default: "\"${CURRENT_DATE}\""
    --time VALUE            specify time
        -t                      default: "\"${CURRENT_TIME}\""
    --quiet                 less verbose
        -q                      default: "\"${QUIET}\""

Example: sudo ./$(basename $0) --name \"myos\" --snap_channel \"candidate\" -q

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
        -n|--name)
            NAME=$2
            shift
            ;;
        -arch|--os_arch)
            BASE_OS_ARCH=$2
            shift
            ;;
        -sc|--snap_channel)
            SNAP_CHANNEL=$2
            shift
            ;;
        -p|--preempt)
            PREEMPT=$2
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


##########################################################################################
echo "[INFO] Check apt update, upgrade, autoremove, clean"
##########################################################################################
UPDATE=$(apt-get -y ${ENABLE_QQ} update)
DEBIAN_FRONTEND=noninteractive apt-get -yq --force-yes ${ENABLE_QQ} upgrade
DEBIAN_FRONTEND=noninteractive apt-get -y ${ENABLE_QQ} autoremove
DEBIAN_FRONTEND=noninteractive apt-get -y ${ENABLE_QQ} autoclean
DEBIAN_FRONTEND=noninteractive apt-get -y ${ENABLE_QQ} clean


##########################################################################################
echo "[INFO] Install packages"
##########################################################################################
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections
OS_VS=$(cat /etc/os-release | grep VERSION= | tr -d -c [0-9.] | head -c 5)
INSTALL_PACKAGES=(
    "at" # required for scheduling
    "apt-transport-https" 
    #"awscli" # use v2 instead
    "barcode" 
    "clevis" "clevis-luks" "clevis-tpm2" "clevis-systemd" "clevis-initramfs" "clevis-udisks2"
    "collectd" # system parameters
    # "default-jdk" # gets lastest jdk (e.g. openjdk-11-jdk)
    "docker.io" 
    "docker-compose" 
    "grub-efi-amd64-signed" 
    "htop" 
    "incron" 
    #"iptables-persistent" # will be deprecated
    "jailkit" 
    "jq" 
    "linux-lowlatency-hwe-${OS_VS}" 
    "nftables" 
    #"nftlb" # load balancer requires setup
    #"openjdk-8-jdk:amd64" # services depended on v8
    "openssl" 
    "openssh-server" 
    "python3-pip" 
    "qrencode" 
    "rng-tools-debian" # previous rng-tools is deprecated in 22.04
    "ruby" 
    "sshguard" 
    "shim" 
    "shim-signed" 
    "tmux" 
    "tree" 
    "ttf-mscorefonts-installer" 
    "unzip" 
    "usbguard" 
    "zip" 
)
for PACKAGE in "${INSTALL_PACKAGES[@]}"; do
    if [ -z "$(dpkg -l | grep "i  ${PACKAGE} ")" ]; then
        DEBIAN_FRONTEND=noninteractive apt-get -y ${ENABLE_QQ} install ${PACKAGE};
        echo "[INFO] Installed '${PACKAGE}'";
    fi
done


##########################################################################################
echo "[INFO] Purge default packages"
##########################################################################################
echo gdm3 shared/default-x-display-manager select lightdm | debconf-set-selections
PURGE_PACKAGES=(
    "apport" "aspell" "atril" 
    "baobab" "blueman" "bluez" "brltty" 
    "catfish" "cheese-common" "chromium-browser" "colord" 
    "espeak" "evolution-data-server" 
    "firefox" 
    "gdm" "gimp" "git" "git-man" "gnome-accessibility-themes" "gnome-control-center" "gnome-desktop3-data" 
    "gnome-disk-utility" "gnome-font-viewer" "gnome-keyring" "gnome-menus" "gnome-mines" "gnome-software" 
    "gnome-startup-applications" "gnome-sudoku" "gnome-system-tools" "gnome-themes-extra" 
    "hexchat" 
    "imagemagick" 
    "kerneloops" 
    "libreoffice" "linux-*generic" 
    "mate-calc" "menulibre" "modemmanager" "mousepad" "mugshot" "mutter" 
    "onboard" 
    "p7zip" "parole" "pidgin" "plymouth-theme-xubuntu-" "pocketsphinx-en-us" "python2.7" 
    "rhythmbox" "ristretto" "rygel" 
    "sane-airscan" "sane-utils" "simple-scan" "sgt-" "snapd" "software-properties-gtk" "speech-dispatcher" 
    "thunar" "thunderbird" "transmission-" "tumbler" 
    "ubuntu-wallpapers" "upower" 
    "wamerican" "whoopsie" 
    "xfburn" 
    "xfce4-appfinder" "xfce4-cpugraph-plugin" "xfce4-dict" "xfce4-indicator-plugin" "xfce4-mailwatch-plugin" 
    "xfce4-netload-plugin" "xfce4-notes" "xfce4-panel" "xfce4-power-manager" "xfce4-power-manager-plugins" 
    "xfce4-pulseaudio-plugin" "xfce4-screens" "xfce4-statusnotifier-plugin" "xfce4-systemload-plugin" 
    "xfce4-taskmanager" "xfce4-terminal" "xfce4-verve-plugin" "xfce4-weather-plugin" "xfce4-xkb-plugin" 
    "xubuntu-" "xul-ext-ubufox" "xwayland" 
    "yelp" 
)
# whoospie throws error as missing file
if [ ! -z "$(dpkg -l | grep "i  whoopsie ")" ]; then
    if [ ! -f "/var/lib/whoopsie/whoopsie-id" ]; then
        mkdir -p "/var/lib/whoopsie";
        touch "/var/lib/whoopsie/whoopsie-id";
    fi
fi
for PACKAGE in "${PURGE_PACKAGES[@]}"; do
    if [ ! -z "$(dpkg -l | grep "i  ${PACKAGE}.*")" ]; then
        DEBIAN_FRONTEND=noninteractive apt-get -y ${ENABLE_QQ} purge "${PACKAGE}*" || true;
        echo "[INFO] Purged package '${PACKAGE}'";
    fi
done

# purge non-english language packs
LANGUAGES=($(dpkg -l | grep "language-pack-" | grep -v "language-pack.*-en.*" | cut -d ' ' -f3))
for PACKAGE in "${LANGUAGES[@]}"; do
    DEBIAN_FRONTEND=noninteractive apt-get -y ${ENABLE_QQ} purge "${PACKAGE}*";
    echo "[INFO] Purged package '${PACKAGE}'"
done

# purge snap chromium and snap existance in favor of google-chrome-stable.deb
rm -rf /var/lib/snapd /snap /var/snap;


##########################################################################################
echo "[INFO] Check apt autoremove, clean"
##########################################################################################
DEBIAN_FRONTEND=noninteractive apt-get -y ${ENABLE_QQ} autoremove
DEBIAN_FRONTEND=noninteractive apt-get -y ${ENABLE_QQ} autoclean
DEBIAN_FRONTEND=noninteractive apt-get -y ${ENABLE_QQ} clean


./install_google_chrome.sh ${ENABLE_QUIET}
#./install_aws_cliv2.sh ${ENABLE_QUIET}
#./install_aws_cloudwatch.sh
#./install_aws_codedeploy.sh
#./install_aws_ssm.sh

##########################################################################################
echo "[INFO] Set default system settings"
##########################################################################################
##############################
echo "[INFO] Install additional fonts"
##############################
# https://fontzone.net/font-details/microsoft-sans-serif
# https://fontzone.net/downloadfile/microsoft-sans-serif
# http://www.fonts100.com/font+89945_Segoe+UI+Black.html
# https://www.fonts100.com/89945/segoeuiblack.zip
if [ -d "fonts" ]; then
    if [ -d "fonts/msttcorefonts" ]; then
        FONTS_DIR="/usr/share/fonts/truetype/msttcorefonts";
        mkdir -p ${FONTS_DIR};
        mv fonts/msttcorefonts/*.ttf ${FONTS_DIR}/;
        fc-cache -f ${FONTS_DIR}/;
        echo "[INFO] Installed Microsoft True Type Core Fonts";
    fi
    if [ -d "fonts/tahoma" ]; then
        FONTS_DIR="/usr/share/fonts/truetype/msttcorefonts";
        mkdir -p ${FONTS_DIR};
        mv fonts/tahoma/*.ttf ${FONTS_DIR}/;
        fc-cache -f ${FONTS_DIR}/;
        echo "[INFO] Installed Microsoft True Type Tahoma Fonts";
    fi
    if [ -d "fonts/vista" ]; then
        FONTS_DIR="/usr/share/fonts/truetype/vista";
        mkdir -p ${FONTS_DIR};
        mv fonts/vista/*.ttf ${FONTS_DIR}/;
        fc-cache -f ${FONTS_DIR}/;
        echo "[INFO] Installed Microsoft Vista Fonts";
    fi
fi

##############################
FILEPATH="/usr/share/grub/default/grub"
# FILEPATH="/etc/default/grub"
echo "[INFO] Modify and update '${FILEPATH}'"
##############################
if [ ! -z "$(grep 'GRUB_CMDLINE_LINUX=\"\"' ${FILEPATH})" ]; then
    sed -i "s/GRUB_TIMEOUT=0/GRUB_TIMEOUT=0\nGRUB_DISABLE_OS_PROBER=true/" ${FILEPATH};
    sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=\"quiet\"/" ${FILEPATH};
    # manually creating interface link, so removing net.ifnames=0 biosdevname=0
    sed -i "s/GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX=\"ipv6.disable=1 nosgx tpm_tis.interrupts=0 ${PREEMPT}\"/" ${FILEPATH};
    sed -i "s/#GRUB_DISABLE_RECOVERY/GRUB_DISABLE_RECOVERY/" ${FILEPATH};
    cp ${FILEPATH} /etc/default/grub;
    update-grub;
    echo "[INFO] Modified '${FILEPATH}' and updated grub";
fi

##############################
echo "[INFO] Disable auto-update"
##############################
sed -i "s/Update-Package-Lists \"1\"/Update-Package-Lists \"0\"/" /etc/apt/apt.conf.d/10periodic
sed -i "s/Download-Upgradeable-Packages \"1\"/Download-Upgradeable-Packages \"0\"/" /etc/apt/apt.conf.d/10periodic
sed -i "s/AutocleanInterval \"1\"/AutocleanInterval \"0\"/" /etc/apt/apt.conf.d/10periodic
sed -i "s/Update-Package-Lists \"1\"/Update-Package-Lists \"0\"/" /etc/apt/apt.conf.d/20auto-upgrades
sed -i "s/Unattended-Upgrade \"1\"/Unattended-Upgrade \"0\"/" /etc/apt/apt.conf.d/20auto-upgrades
sed -i "s/Prompt=.*/Prompt=never/" /etc/update-manager/release-upgrades

##############################
echo "[INFO] Disable user directories"
##############################
sed -i "s/enabled=True/enabled=False/" /etc/xdg/user-dirs.conf

##############################
echo "[INFO] Update USBGuard rules"
##############################
cat > /etc/usbguard/rules.conf <<EOL
allow
EOL

##############################
echo "[INFO] Update RNG-Tools rules"
##############################
FILEPATH="/etc/default/rng-tools-debian"
if [ -z "$(cat ${FILEPATH} | grep "HRNGDEVICE=/dev/urandom")" ]; then
    if [ -z "$(cat ${FILEPATH} | grep "HRNGDEVICE=/dev/null")" ]; then
        echo "HRNGDEVICE=/dev/urandom" >> ${FILEPATH}
    else
        sed -i 's|HRNGDEVICE=/dev/null|HRNGDEVICE=/dev/null\nHRNGDEVICE=/dev/urandom|' ${FILEPATH}
    fi
    echo "[INFO] Updated RNG-Tools rules"
fi

##############################
echo "[INFO] Modify logrotate filename"
##############################
cat > /etc/logrotate.d/rsyslog <<EOL
rotate 7
daily
missingok
notifempty
compress
delaycompress
dateext
dateformat .%Y-%m-%d-%H-%M-%S
extension .log

#/var/log/mail.info
#/var/log/mail.warn
#/var/log/mail.err
#/var/log/mail.log
/var/log/daemon.log
/var/log/kern.log
/var/log/auth.log
/var/log/user.log
/var/log/lpr.log
/var/log/cron.log
/var/log/debug
/var/log/messages
/var/log/syslog
{
    sharedscripts
    postrotate
        /usr/lib/rsyslog/rsyslog-rotate
    endscript
}
EOL

# ##############################
# echo "[INFO] Modify syslog"
# ##############################
# if [ $(grep -c "#\*\.\*;auth,authpriv.none" /etc/rsyslog.d/50-default.conf) -lt 1 ]; then sed -i "s/*.*;auth,authpriv.none/#*.*;auth,authpriv.none/" /etc/rsyslog.d/50-default.conf; fi
# if [ $(grep -c "#mai.\*" /etc/rsyslog.d/50-default.conf) -lt 1 ]; then sed -i "s/mail.\*/#mail.*/" /etc/rsyslog.d/50-default.conf; fi
# if [ $(grep -c "#mail.err " /etc/rsyslog.d/50-default.conf) -lt 1 ]; then sed -i "s/mail.err/#mail.err/" /etc/rsyslog.d/50-default.conf; fi

##############################
echo "[INFO] Enable kiosk mode"
##############################
rm -rf /etc/skel/.config
mkdir -p /etc/skel/.config/autostart
cat > /etc/skel/.config/autostart/Kiosk.desktop <<EOL
[Desktop Entry]
Encoding=UTF-8
Version=0.9.4
Type=Application
Name=Kiosk
Comment=Kiosk
Exec=sh -c "while true; do [ ! -z \"\$(nc -v -w 0 127.0.0.1 80 2>&1 | grep succeeded)\" ] && /usr/bin/google-chrome-stable --kiosk --disable-gpu --no-first-run --no-default-browser-check --ignore-certificate-errors --password-store=basic --disable-infobars --disable-pinch --user-data-dir=\"\" --disable-session-storage --load-extension=\"/home/\$USER/pflmllfnnabikmfkkaddkoolinlfninn/\" https://127.0.0.1:80; sleep 1; done"
OnlyShowIn=XFCE;
RunHook=0
StartupNotify=false
Terminal=false
Hidden=false
EOL

##############################
echo "[INFO] Set default user kiosk, disable mouse cursor and blank screen"
##############################
cat > /etc/lightdm/lightdm.conf <<EOL
[Seat:*]
autologin-guest=false
autologin-user=kiosk
autologin-user-timeout=0
user-session=xfce
# "-s 0" screen-saver timeout to 0
# "-dpms" disable display power management services
# "-nocursor" disable mouse cursor
xserver-command = X -s 0 -dpms
EOL

##############################
echo "[INFO] Enable high precision timestamps for logging"
##############################
if [ -z "$(grep '#\$ActionFileDefaultTemplate' /etc/rsyslog.conf)" ]; then
    sed -i 's/^$Action/#\$Action/' /etc/rsyslog.conf;
    echo "[INFO] Enabled high precision timestamps for logging"
fi

##############################
FILEPATH=/usr/share/plymouth/themes/ubuntu-text/ubuntu-text.plymouth
echo "[INFO] Update '${FILEPATH}'"
##############################
if [ -z "$(cat ${FILEPATH} | grep ${NAME})" ]; then
    sed -i 's/title=.*/title='${NAME}'/' ${FILEPATH};
    update-initramfs -u -k all;
    echo "[INFO] Updated '${FILEPATH}'";
fi


##########################################################################################
echo "[INFO] Preseed and post installation"
##########################################################################################
##############################
FILEPATH="/init/create_link.sh"
echo "[INFO] Generate '${FILEPATH}'"
##############################
cat > "${FILEPATH}" <<EOL
#!/bin/bash

# Possible arguments
# --action
#   init: remove existing config and create new one
#   reset: remove existing config and exit script
# --name_wired (override name of wired connections with the default of 'wire')
# --name_wireless (override name of wireless connections with the default of 'wireless')
# --wire_index (override starting index of link naming with the default of 1)
# --wireless_index (override starting index of link naming with the default of 1)
#
# Example: /init/create_link.sh --action init --name_wired lan --wire_index 0

set -e

# Create variables from the named parameters
while [ \$# -gt 0 ]; do
    if [[ \$1 == *"--"* ]]; then
        param="\${1/--/}"
        declare \$param="\$2"
    fi
    shift
done

echo "[INFO] Start '\$(basename \$0)' at '\$(date -u +"%Y-%m-%dT%H:%M:%Sz")'"
TIMER_START=\$(date +%s)

if [ "\${action}" = "init" ]; then
    rm -f /etc/systemd/network/*
elif [ "\${action}" = "reset" ]; then
    rm -f /etc/systemd/network/*;
    echo "[INFO] Removed existing links in '/etc/systemd/network/'";
    exit 0;
fi

# Potential race condition with kernel vs systemd
# If kernel is naming ports as ethX and systemd overrides with this script
# then all ports will fail.  Safe way is to use something else (e.g. wire1)
# instead of eth0.  Override --name_wired with another value if needed
if [ -z "\${name_wired}" ]; then
    name_wired=wire
fi

if [ -z "\${name_wireless}" ]; then
    name_wireless=wireless
fi

if [ -z "\${wire_index}" ]; then
    wire_index=1
fi

if [ -z "\${wireless_index}" ]; then
    wireless_index=1
fi

# link interface name to MAC address
# equivalent of setting net.ifnames=0 biosdevname=0, but more stable since  
# network interfaces can "jump" around if naming is done by kernel
# https://www.freedesktop.org/software/systemd/man/systemd.link.html
create_link () {
    NAME="\$1"
    INDEX="\$2"
    MAC="\$3"
    # increment index if file exists (e.g. ethernet dongle)
    if [ -z "\$(grep "\${MAC}" /etc/systemd/network/* -sH)" ]; then 
        # get largest file name; update index
        NEW_INDEX=\$(ls /etc/systemd/network/ | grep "10-\${NAME}" | sort -r | head -1 | sed "s|10-\${NAME}||; s|.link||")
        if [ -z "\${NEW_INDEX}" ]; then
            INDEX="\${INDEX}"
        elif [ "\${INDEX}" -le "\${NEW_INDEX}" ]; then
            INDEX=\$((NEW_INDEX + 1))
        fi
    else
        echo "[DEBUG] File exists \$(grep "\${MAC}" /etc/systemd/network/* -sH | cut -d ':' -f1)";
        return
    fi
    ITF_NAME="\${NAME}\${INDEX}"
    FILE_PATH="/etc/systemd/network/10-\${ITF_NAME}.link"
    echo "[INFO] Create file '\${FILE_PATH}' with content:"
    echo "[Match]" > "\${FILE_PATH}"
    echo "MACAddress=\${MAC}" >> "\${FILE_PATH}"
    echo " " >> "\${FILE_PATH}"
    echo "[Link]" >> "\${FILE_PATH}"
    echo "Name=\${ITF_NAME}" >> "\${FILE_PATH}"
    cat "\${FILE_PATH}"
}

WIRE_INDEX=\${wire_index}
WIRELESS_INDEX=\${wireless_index}
# sort MAC and its interface name
# https://www.kernel.org/doc/Documentation/ABI/testing/sysfs-class-net
MAC_DEVICES=\$(grep "" /sys/class/net/*/address -sH | sed 's|/sys/class/net/||g; s|/address||g' | awk -F ":" '{print \$2":"\$3":"\$4":"\$5":"\$6":"\$7"="\$1}' | sort)
for DEVICE in \${MAC_DEVICES}; do
    DEVICE_NAME="\$(echo \${DEVICE} | cut -d '=' -f2)"
    MAC="\$(echo \${DEVICE} | cut -d '=' -f1)"
    DEVICE_TYPE="\$(cat /sys/class/net/\${DEVICE_NAME}/type)"
    # skip virtual devices (e.g. docker, bridge, etc)
    DEVICE_ADDRESS_TYPE="\$(cat /sys/class/net/\${DEVICE_NAME}/addr_assign_type)"
    if [ "\${DEVICE_ADDRESS_TYPE}" -ne "0" ]; then
        echo "[DEBUG] Skipping virtual device '\${DEVICE_NAME}' with MAC '\${MAC}'"
        continue
    fi
    echo "[DEBUG] Found device '\${DEVICE_NAME}' with MAC '\${MAC}'"
    # https://elixir.bootlin.com/linux/latest/source/include/uapi/linux/if_arp.h
    if [ -d "/sys/class/net/\${DEVICE_NAME}/wireless" ]; then DEVICE_TYPE=801; fi
    case "\${DEVICE_TYPE}" in
        1) # ethernet
            create_link "\${name_wired}" "\${WIRE_INDEX}" "\${MAC}"
            WIRE_INDEX=\$((WIRE_INDEX + 1))
            ;;
        772) # loopback
            echo "[DEBUG] IGNORE '\${DEVICE_NAME}' with MAC '\${MAC}'"
            ;;
        801|802|803) # wireless
            create_link "\${name_wireless}" "\${WIRELESS_INDEX}" "\${MAC}"
            WIRELESS_INDEX=\$((WIRELESS_INDEX + 1))
            ;;
        *) # uncategorized
            echo "[ERROR] Unknown device '\${DEVICE_NAME}' with MAC '\${MAC}'"
            ;;
    esac
done

TIMER_END=\$(date +%s)
DURATION=\$((TIMER_END-TIMER_START))
HOURS=\$((DURATION / 3600))
MINUTES=\$(( (DURATION % 3600) / 60 ));
SECONDS=\$(( (DURATION % 3600) % 60 ));
echo "[INFO] Duration of '\$(basename \$0)' is '\${HOURS}h \${MINUTES}m \${SECONDS}s'"
echo "[INFO] End '\$(basename \$0)' at '\$(date -u +"%Y-%m-%dT%H:%M:%Sz")'"
EOL
chmod 700 "${FILEPATH}"
if [ "${QUIET}" = false ]; then
    cat "${FILEPATH}"
fi

##############################
FILEPATH="/init/preseed/manage_services.sh"
echo "[INFO] Generate '${FILEPATH}'"
##############################
cat > "${FILEPATH}" <<EOL
#!/bin/bash

# set -e

echo "[INFO] Start '\$(basename \$0)' at '\$(date -u +"%Y-%m-%dT%H:%M:%Sz")'"
TIMER_START=\$(date +%s)

DISABLE_PACKAGES=(
    "avahi-daemon.service" 
    "codedeploy-agent.service" 
    "codemeter-webadmin.service" 
    "containerd.service" 
    "cups.service" 
    "cups-browsed.service" 
    "docker.service" 
    "docker.socket" 
    "ondemand.service" 
    "NetworkManager-wait-online.service" 
    "upower.service" 
    "whoopsie.service" 
)

for PACKAGE in "\${DISABLE_PACKAGES[@]}"; do
    if [ ! -z "\$(systemctl list-unit-files | grep "\${PACKAGE}" )" ]; then
        systemctl disable "\${PACKAGE}";
        echo "[INFO] Disabled package '\${PACKAGE}'";
    fi
done


ENABLE_PACKAGES=(
    "amazon-cloudwatch-agent.service" 
)

for PACKAGE in "\${ENABLE_PACKAGES[@]}"; do
    systemctl enable "\${PACKAGE}";
    echo "[INFO] Enabled package '\${PACKAGE}'";
done

TIMER_END=\$(date +%s)
DURATION=\$((TIMER_END-TIMER_START))
HOURS=\$((DURATION / 3600))
MINUTES=\$(( (DURATION % 3600) / 60 ));
SECONDS=\$(( (DURATION % 3600) % 60 ));
echo "[INFO] Duration of '\$(basename \$0)' is '\${HOURS}h \${MINUTES}m \${SECONDS}s'"
echo "[INFO] End '\$(basename \$0)' at '\$(date -u +"%Y-%m-%dT%H:%M:%Sz")'"
EOL
chmod 700 "${FILEPATH}"
if [ "${QUIET}" = false ]; then
    cat "${FILEPATH}"
fi


##############################
FILEPATH="/init/preseed/touchscreen.sh"
echo "[INFO] Generate '${FILEPATH}'"
##############################
cat > "${FILEPATH}" <<EOL
#!/bin/bash

set -e

echo "[INFO] Start '\$(basename \$0)' at '\$(date -u +"%Y-%m-%dT%H:%M:%Sz")'"
TIMER_START=\$(date +%s)

if [ ! -z "\$(udevadm info --export-db | grep ID_INPUT_TOUCHSCREEN)" ]; then
   sed -i "s/xserver-command =.*/xserver-command = X -s 0 -dpms -nocursor/" /etc/lightdm/lightdm.conf;
   echo "[INFO] Disabled mouse cursor";
fi

TIMER_END=\$(date +%s)
DURATION=\$((TIMER_END-TIMER_START))
HOURS=\$((DURATION / 3600))
MINUTES=\$(( (DURATION % 3600) / 60 ));
SECONDS=\$(( (DURATION % 3600) % 60 ));
echo "[INFO] Duration of '\$(basename \$0)' is '\${HOURS}h \${MINUTES}m \${SECONDS}s'"
echo "[INFO] End '\$(basename \$0)' at '\$(date -u +"%Y-%m-%dT%H:%M:%Sz")'"
EOL
chmod 700 "${FILEPATH}"
if [ "${QUIET}" = false ]; then
    cat "${FILEPATH}"
fi

##############################
FILEPATH="/init/preseed/unlock_disk.sh"
echo "[INFO] Generate '${FILEPATH}'"
##############################
cat > "${FILEPATH}" <<EOL
#!/bin/bash

# Possible arguments
# --slot (override the LUKS unlock slot with default of 1)
# --pcrs (override the PCR slots with the default of '0')
#
# Example: /init/preseed/unlock_disk.sh --slot 2 --pcrs '0,7'

set -e

# Create variables from the named parameters
while [ \$# -gt 0 ]; do
    if [[ \$1 == *"--"* ]]; then
        param="\${1/--/}"
        declare \$param="\$2"
    fi
    shift
done

echo "[INFO] Start '\$(basename \$0)' at '\$(date -u +"%Y-%m-%dT%H:%M:%Sz")'"
TIMER_START=\$(date +%s)

# check dependencies
if [ -z "\$(whereis clevis | cut -d":" -f2)" ]; then echo "[ERROR] Missing clevis"; exit 0; fi
# assuming one partition
DEVICE=\$(lsblk -flip | grep crypto_LUKS | tail -1 | awk '{print \$1}')
if [ -z \${DEVICE} ]; then echo "[ERROR] Missing encrypted partition"; exit 0; fi

if [ -z "\${slot}" ]; then
    SLOT="1";
else
    SLOT=\${slot};
fi

if [ -z "\${pcrs}" ]; then
    PCRS="0";
else
    PCRS=\${pcrs};
fi

# auto unlock LUKS
if [ -c "/dev/tpm0" ] || [ -c "/dev/tpmrm0" ]; then
    echo "[INFO] Bind passphrase to slot \${SLOT}";
    clevis luks unbind -f -d \${DEVICE} -s \${SLOT};
    printf "${NAME}\n" | clevis luks bind -d \${DEVICE} tpm2 '{"pcr_bank":"sha256", "pcr_ids":"'\${PCRS}'"}' -s \${SLOT};
    echo "[INFO] Update initramfs";
    update-initramfs -u -k all;
else
    "echo [WARN] Did not find encrypted device";
fi

TIMER_END=\$(date +%s)
DURATION=\$((TIMER_END-TIMER_START))
HOURS=\$((DURATION / 3600))
MINUTES=\$(( (DURATION % 3600) / 60 ));
SECONDS=\$(( (DURATION % 3600) % 60 ));
echo "[INFO] Duration of '\$(basename \$0)' is '\${HOURS}h \${MINUTES}m \${SECONDS}s'"
echo "[INFO] End '\$(basename \$0)' at '\$(date -u +"%Y-%m-%dT%H:%M:%Sz")'"
EOL
chmod 700 "${FILEPATH}"
if [ "${QUIET}" = false ]; then
    cat "${FILEPATH}"
fi

##############################
FILEPATH="/init/preseed/add_luks.sh"
echo "[INFO] Generate '${FILEPATH}'"
##############################
cat > "${FILEPATH}" <<EOL
#!/bin/bash

# Possible arguments
# --slot (override the LUKS unlock slot with default of 7)
#
# Example: /init/preseed/add_luks.sh --slot 3

set -e

# Create variables from the named parameters
while [ \$# -gt 0 ]; do
    if [[ \$1 == *"--"* ]]; then
        param="\${1/--/}"
        declare \$param="\$2"
    fi
    shift
done

echo "[INFO] Start '\$(basename \$0)' at '\$(date -u +"%Y-%m-%dT%H:%M:%Sz")'"
TIMER_START=\$(date +%s)

if [ -z "\$(whereis cryptsetup | cut -d":" -f2)" ]; then echo "[ERROR] Missing cryptsetup"; exit 0; fi

if [ -z "\${slot}" ]; then
    SLOT=7;
else
    SLOT=\${slot};
fi

echo "[INFO] Get LUKS partition"
DEVICE=\$(lsblk -flip | grep crypto_LUKS | tail -1 | awk '{print \$1}')

if [ -z "\$(cryptsetup luksDump \$DEVICE | grep "\${SLOT}: luk")" ]; then
    printf "${NAME}\n${NAME}\n${NAME}\n" | cryptsetup luksAddKey \$DEVICE --key-slot \${SLOT};
    echo "[INFO] Added backup LUKS to slot \${SLOT}";
else
    echo "[WARN] Did not add backup LUKS to slot \${SLOT}";
fi

TIMER_END=\$(date +%s)
DURATION=\$((TIMER_END-TIMER_START))
HOURS=\$((DURATION / 3600))
MINUTES=\$(( (DURATION % 3600) / 60 ));
SECONDS=\$(( (DURATION % 3600) % 60 ));
echo "[INFO] Duration of '\$(basename \$0)' is '\${HOURS}h \${MINUTES}m \${SECONDS}s'"
echo "[INFO] End '\$(basename \$0)' at '\$(date -u +"%Y-%m-%dT%H:%M:%Sz")'"
EOL
chmod 700 "${FILEPATH}"
if [ "${QUIET}" = false ]; then
    cat "${FILEPATH}"
fi

##############################
FILEPATH="/init/preseed/set_network.sh"
echo "[INFO] Generate '${FILEPATH}'"
##############################
cat > "${FILEPATH}" <<EOL
#!/bin/bash

# Possible arguments
# --name (override the connection name with default of 'Wired connection 1')
# --interface (override the ethernet interface name with default of 'wire1')
# --address (override the static IP address with default of '192.168.0.10/22')
# --gateway (override the gateway with default of '192.168.0.1')
# --dns (override the dns with default of '8.8.8.8')
# --manual (override the method with default of 'manual')
# --metric (override the route metric with default of 101)
#
# Example: /init/preseed/set_network.sh --address '192.168.1.10/24' --dns '192.168.1.1' --metric 1000

set -e

# Create variables from the named parameters
while [ \$# -gt 0 ]; do
    if [[ \$1 == *"--"* ]]; then
        param="\${1/--/}"
        declare \$param="\$2"
    fi
    shift
done

echo "[INFO] Start '\$(basename \$0)' at '\$(date -u +"%Y-%m-%dT%H:%M:%Sz")'"
TIMER_START=\$(date +%s)

if [ -z "\${name}" ]; then
    name="Wired connection 1"
fi

if [ -z "\${interface}" ]; then
    interface="wire1"
fi

if [ -z "\${address}" ]; then
    address="192.168.0.1/22"
fi

if [ -z "\${gateway}" ]; then
    gateway="192.168.0.1"
fi

if [ -z "\${dns}" ]; then
    dns="8.8.8.8"
fi

if [ -z "\${method}" ]; then
    method="manual"
fi

if [ -z "\${metric}" ]; then
    metric="101"
fi

NETWORK_FILE="/etc/NetworkManager/system-connections/"\${name}".nmconnection"
cat > "\${NETWORK_FILE}" <<EOL1
[connection]
id=\${name}
uuid=\$(uuidgen)
type=ethernet
autoconnect-priority=-999
interface-name=\${interface}
timestamp=\$(date +%s)

[ethernet]

[ipv4]
address1=\${address},\${gateway}
dns=\${dns};
method=\${method}
route-metric=\${metric}

[ipv6]
addr-gen-mode=stable-privacy
method=auto

[proxy]
EOL1
chmod 600 "\${NETWORK_FILE}"
cat "\${NETWORK_FILE}"

TIMER_END=\$(date +%s)
DURATION=\$((TIMER_END-TIMER_START))
HOURS=\$((DURATION / 3600))
MINUTES=\$(( (DURATION % 3600) / 60 ));
SECONDS=\$(( (DURATION % 3600) % 60 ));
echo "[INFO] Duration of '\$(basename \$0)' is '\${HOURS}h \${MINUTES}m \${SECONDS}s'"
echo "[INFO] End '\$(basename \$0)' at '\$(date -u +"%Y-%m-%dT%H:%M:%Sz")'"
EOL
chmod 700 "${FILEPATH}"
if [ "${QUIET}" = false ]; then
    cat "${FILEPATH}"
fi

##############################
FILEPATH="/init/preseed/update_initramfs.sh"
echo "[INFO] Generate '${FILEPATH}'"
##############################
cat > "${FILEPATH}" <<EOL
#!/bin/bash

# Possible arguments
# --action (specify the update method)
#   create: create new initramfs
#   update: update existing initramfs
#
# Example: /init/preseed/update_initramfs.sh --action create

set -e

# Create variables from the named parameters
while [ \$# -gt 0 ]; do
    if [[ \$1 == *"--"* ]]; then
        param="\${1/--/}"
        declare \$param="\$2"
    fi
    shift
done

echo "[INFO] Start '\$(basename \$0)' at '\$(date -u +"%Y-%m-%dT%H:%M:%Sz")'"
TIMER_START=\$(date +%s)

if [ "\${action}" = "create" ]; then
    update-initramfs -c -k all;
    echo "[INFO] Rebuilt initramfs";
elif [ "\${action}" = "update" ]; then
    update-initramfs -u -k all;
    echo "[INFO] Updated initramfs";
fi

TIMER_END=\$(date +%s)
DURATION=\$((TIMER_END-TIMER_START))
HOURS=\$((DURATION / 3600))
MINUTES=\$(( (DURATION % 3600) / 60 ));
SECONDS=\$(( (DURATION % 3600) % 60 ));
echo "[INFO] Duration of '\$(basename \$0)' is '\${HOURS}h \${MINUTES}m \${SECONDS}s'"
echo "[INFO] End '\$(basename \$0)' at '\$(date -u +"%Y-%m-%dT%H:%M:%Sz")'"
EOL
chmod 700 "${FILEPATH}"
if [ "${QUIET}" = false ]; then
    cat "${FILEPATH}"
fi

##############################
FILEPATH="/init/preseed/update_grub.sh"
echo "[INFO] Generate '${FILEPATH}'"
##############################
cat > "${FILEPATH}" <<EOL
#!/bin/bash

set -e

echo "[INFO] Start '\$(basename \$0)' at '\$(date -u +"%Y-%m-%dT%H:%M:%Sz")'"
TIMER_START=\$(date +%s)

cp /usr/share/grub/default/grub /etc/default/grub
echo "[INFO] Copied grub file"

update-grub
echo "[INFO] Updated grub"

TIMER_END=\$(date +%s)
DURATION=\$((TIMER_END-TIMER_START))
HOURS=\$((DURATION / 3600))
MINUTES=\$(( (DURATION % 3600) / 60 ));
SECONDS=\$(( (DURATION % 3600) % 60 ));
echo "[INFO] Duration of '\$(basename \$0)' is '\${HOURS}h \${MINUTES}m \${SECONDS}s'"
echo "[INFO] End '\$(basename \$0)' at '\$(date -u +"%Y-%m-%dT%H:%M:%Sz")'"
EOL
chmod 700 "${FILEPATH}"
if [ "${QUIET}" = false ]; then
    cat "${FILEPATH}"
fi

##############################
FILEPATH="/init/preseed/preseed.sh"
echo "[INFO] Generate '${FILEPATH}'"
##############################
cat > "${FILEPATH}" <<EOL
#!/bin/bash

# set -e

LOG_PATH="/var/log/init/preseed.log"
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>\${LOG_PATH} 2>&1

echo "[INFO] Start '\$(basename \$0)' at '\$(date -u +"%Y-%m-%dT%H:%M:%Sz")'"
TIMER_START=\$(date +%s)

/init/create_link.sh --action init
/init/preseed/manage_services.sh
/init/preseed/touchscreen.sh
/init/preseed/unlock_disk.sh
/init/preseed/add_luks.sh
/init/preseed/set_network.sh
/init/preseed/update_initramfs.sh --action update
/init/preseed/update_grub.sh
adduser kiosk --gecos "" --disabled-password

rm -rf /init/preseed


TIMER_END=\$(date +%s)
DURATION=\$((TIMER_END-TIMER_START))
HOURS=\$((DURATION / 3600))
MINUTES=\$(( (DURATION % 3600) / 60 ));
SECONDS=\$(( (DURATION % 3600) % 60 ));
echo "[INFO] Duration of '\$(basename \$0)' is '\${HOURS}h \${MINUTES}m \${SECONDS}s'"
echo "[INFO] End '\$(basename \$0)' at '\$(date -u +"%Y-%m-%dT%H:%M:%Sz")'"
EOL
chmod 700 "${FILEPATH}"
if [ "${QUIET}" = false ]; then
    cat "${FILEPATH}"
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
echo "[INFO] Kernel management"
##########################################################################################
##############################
echo "[INFO] Remove all kernels except latest"
##############################
KERNEL_COUNT=$(ls -r /lib/modules | wc -l)
if [ ${KERNEL_COUNT} -gt 1 ]; then
    KERNELS=$(ls -r /lib/modules | tail -n+2 | sed 's/-generic//g; s/-lowlatency//g')
    for KERNEL in ${KERNELS}; do
        DEBIAN_FRONTEND=noninteractive apt-get -y ${ENABLE_QQ} purge linux-*${KERNEL}*;
        echo "[INFO] Removed kernel '${KERNEL}'";
    done
fi

##############################
echo "[INFO] Rebuild kernel initramfs"
##############################
depmod -a $(ls -r /lib/modules | head -1)
update-initramfs -c -k all;


##########################################################################################
echo "[INFO] Generate '${LOG_PATH}/dpkg_manifest.csv'"
##########################################################################################
cat > ${LOG_PATH}/dpkg_manifest.csv <<EOL
Package,Version,Installed-Size(KB)
`dpkg-query -W --showformat='${Package},${Version},${Installed-Size}\n'`
EOL

echo "[INFO] Generate '${LOG_PATH}/filesystem.manifest'"
cat > ${LOG_PATH}/filesystem.manifest <<EOL
`dpkg-query -W --showformat='${Package} ${Version}\n'`
EOL


##########################################################################################
echo "[INFO] Generate slideshow"
##########################################################################################
INSTALLED_PACKAGES=""
SPACES="&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"
PACKAGES=(
    "at ($(dpkg -l | grep "i  at " | head -1 | awk '{print $3}' | cut -d '-' -f1))"
    "AWS-CLI ($(aws --version | cut -d' ' -f1 | cut -d '/' -f2))"
    "AWS-CloudWatch ($(dpkg -l | grep "i  amazon-cloudwatch-agent " | head -1 | awk '{print$3}' | cut -d '-' -f1))"
    "AWS-CodeDeploy ($(dpkg -l | grep "i  codedeploy-agent " | head -1 | awk '{print$3}' | cut -d '-' -f1))"
    "AWS-SSM ($(dpkg -l | grep "i  amazon-ssm-agent " | head -1 | awk '{print$3}' | cut -d '-' -f1))"
    "barcode ($(dpkg -l | grep "i  barcode " | head -1 | awk '{print$3}' | cut -d '-' -f1))"
    "Chrome ($(dpkg -l | grep "i  google-chrome-stable " | head -1 | awk '{print$3}' | cut -d '-' -f1))"
    "Clevis initramfs/luks/systemd/tpm2/udisks2 ($(dpkg -l | grep "i  clevis " | head -1 | awk '{print $3}' | cut -d '-' -f1))"
    "CollectD ($(dpkg -l | grep "i  collectd " | head -1 | awk '{print$3}' | cut -d '-' -f1))"
    "cURL ($(dpkg -l | grep "i  curl " | head -1 | awk '{print$3}' | cut -d '-' -f1))"
    "default-jdk ($(dpkg -l | grep "i  default-jdk " | head -1 | awk '{print$3}' | cut -d ':' -f2 | cut -d '-' -f1))"
    "Docker ($(dpkg -l | grep "i  docker.io " | head -1 | awk '{print$3}' | cut -d '-' -f1))"
    "Docker Compose ($(dpkg -l | grep "i  docker-compose " | head -1 | awk '{print$3}' | cut -d '-' -f1))"
    "FTP client ($(dpkg -l | grep "i  ftp " | head -1 | awk '{print$3}' | cut -d '-' -f1))"
    "htop ($(dpkg -l | grep "i  htop " | head -1 | awk '{print$3}' | cut -d '-' -f1))"
    "incron ($(dpkg -l | grep "i  incron " | head -1 | awk '{print$3}' | cut -d '-' -f1))"
    "jailkit ($(dpkg -l | grep "i  jailkit " | head -1 | awk '{print $3}' | cut -d '-' -f1))"
    "jq ($(dpkg -l | grep "i  jq " | head -1 | awk '{print$3}' | cut -d '-' -f1))"
    "openjdk-8-jdk ($(dpkg -l | grep "i  openjdk-8-jdk:" | head -1 | awk '{print$3}' | cut -d '-' -f1))"
    "OpenSSH client/server/sftp-server ($(dpkg -l | grep "i  openssh-client " | head -1 | awk '{print$3}' | cut -d '-' -f1 | cut -d ':' -f2))"
    "OpenSSL ($(dpkg -l | grep "i  openssl " | head -1 | awk '{print$3}' | cut -d '-' -f1))"
    "Python3 ($(dpkg -l | grep "i  python3 " | head -1 | awk '{print$3}' | cut -d '-' -f1))"
    "Python3-pip ($(dpkg -l | grep "i  python3-pip " | head -1 | awk '{print$3}' | cut -d '+' -f1))"
    "qrencode ($(dpkg -l | grep "i  qrencode " | head -1 | awk '{print$3}' | cut -d '-' -f1)) "
    "Ruby ($(dpkg -l | grep "i  ruby " | head -1 | awk '{print$3}' | cut -d ':' -f2 | cut -d '~' -f1))"
    "rsync ($(dpkg -l | grep "i  rsync " | head -1 | awk '{print$3}' | cut -d '-' -f1))"
    "Snapd ($(dpkg -l | grep "i  snapd " | head -1 | awk '{print$3}' | cut -d '+' -f1))"
    "SSHGuard ($(dpkg -l | grep "i  sshguard " | head -1 | awk '{print$3}' | cut -d '-' -f1))"
    "Telnet client ($(dpkg -l | grep "i  telnet " | head -1 | awk '{print$3}' | cut -d '-' -f1))"
    "tmux ($(dpkg -l | grep "i  tmux " | head -1 | awk '{print$3}' | cut -d '-' -f1))"
    "unzip ($(dpkg -l | grep "i  unzip " | head -1 | awk '{print$3}' | cut -d '-' -f1))"
    "USBGuard ($(dpkg -l | grep "i  usbguard " | head -1 | awk '{print$3}' | cut -d '+' -f1))"
    "Wget ($(dpkg -l | grep "i  wget " | head -1 | awk '{print$3}' | cut -d '-' -f1))"
    "zip ($(dpkg -l | grep "i  zip " | head -1 | awk '{print$3}' | cut -d '-' -f1))"
)
for PACKAGE in "${PACKAGES[@]}"; do
    if [ ! -z "$(echo "${PACKAGE}" | grep -o "(.*)" | sed 's/(//; s/)//')" ]; then
        if [ -z "$(echo ${INSTALLED_PACKAGES})" ]; then
            INSTALLED_PACKAGES="${PACKAGE}"
        else
            INSTALLED_PACKAGES="${INSTALLED_PACKAGES}${SPACES}${PACKAGE}"
        fi
    fi
done
CUSTOM_OS_POINT_RELEASE=$(cat /etc/os-release | grep VERSION= | tr -d -c [0-9.])
FILEPATH="/usr/share/ubiquity-slideshow/slides/index.html"
cat > "${FILEPATH}" <<EOL
<!DOCTYPE html>
<html lang="en">
    <head>
        <title>Custom OS</title>
        <style>
            body { background: #cecece; font-size: 85%; line-height: 1.6em; }
            h2 { margin-top: 0px; margin-bottom: 5px; }
            h4,ul,li { margin: 0px; }
        </style>
    </head>
    <body>
        <h2>${NAME} ${CUSTOM_OS_POINT_RELEASE} ${CURRENT_DATE}</h2>
        <h4>Kernel ($(ls -r /lib/modules | head -1) ${BASE_OS_ARCH})</h4>
        <h4>Included software packages:</h4>
        <p>${INSTALLED_PACKAGES}</p>
    </body>
</html>
EOL
if [ "${QUIET}" = false ]; then
    cat "${FILEPATH}"
fi


##########################################################################################
# success flag, required!
echo "[INFO] Successful Customization"
##########################################################################################


TIMER_END=$(date +%s)
DURATION=$((TIMER_END-TIMER_START))
HOURS=$((DURATION / 3600))
MINUTES=$(( (DURATION % 3600) / 60 ));
SECONDS=$(( (DURATION % 3600) % 60 ));
echo "[INFO] Duration of '$(basename $0)' is '${HOURS}h ${MINUTES}m ${SECONDS}s'"
echo "[INFO] End '$(basename $0)' at '$(date -u +"%Y-%m-%dT%H:%M:%Sz")'"
