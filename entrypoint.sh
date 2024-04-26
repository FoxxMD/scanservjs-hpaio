#!/bin/sh
set -xve

# Test using the following form:
# export SANED_NET_HOSTS="a|b" AIRSCAN_DEVICES="c|d" DELIMITER="|"; ./entrypoint.sh

# turn off globbing
set -f

# split at newlines only (airscan devices can have spaces in)
IFS='
'

# Get a custom delimiter but default to ;
DELIMITER=${DELIMITER:-;}

# Insert a list of net hosts
if [ ! -z "$SANED_NET_HOSTS" ]; then
  hosts=$(echo $SANED_NET_HOSTS | sed "s/$DELIMITER/\n/")
  for host in $hosts; do
    echo $host >> /etc/sane.d/net.conf
  done
fi

# Insert airscan devices
if [ ! -z "$AIRSCAN_DEVICES" ]; then
  devices=$(echo $AIRSCAN_DEVICES | sed "s/$DELIMITER/\n/")
  for device in $devices; do
    sed -i "/^\[devices\]/a $device" /etc/sane.d/airscan.conf
  done
fi

# Insert pixma hosts
if [ ! -z "$PIXMA_HOSTS" ]; then
  hosts=$(echo $PIXMA_HOSTS | sed "s/$DELIMITER/\n/")
  for host in $hosts; do
    echo "bjnp://$host" >> /etc/sane.d/pixma.conf
  done
fi

unset IFS
set +f

if [ $(dpkg-query -W -f='${Status}' libsane-hpaio 2>/dev/null | grep -c "ok installed") -eq 1 ];
then
  # assume user does not want to install plugin
  HP_PLUGIN="${HP_PLUGIN:=false}"
  if [ "$PLUGIN" != "false" ]; then
    echo "Checking HP_PLUGIN status..."
    # determine installed HPLIP version
    RE="HP Linux Imaging and Printing System \(ver\. (.+?)\)"
    cmd_output=$(hp-plugin --help 2>&1)
    #https://stackoverflow.com/a/2778096
    RAW_VERSION="$(echo "$cmd_output" | sed -rn "s/$RE/\1/p")"
    # Remove ansi coloring so its just a raw string
    #https://stackoverflow.com/a/51141872
    HPLIP_VERSION=$(echo "$RAW_VERSION" | sed 's/\x1B\[[0-9;]\{1,\}[A-Za-z]//g')
    printf 'HPLIP Version: %s\n' "$HPLIP_VERSION"

    # if variable is true then try to determine plugin version automatically
    if [ "$HP_PLUGIN" = "true" ]; then

      # check if plugin is already installed
      # files installed to these locations https://wiki.gentoo.org/wiki/HPLIP#Binary_plugins
      if [ -d /usr/share/hplip/data/firmware ]; then
        printf 'A plugin is already installed. To force (re)install specify version in ENV like HP_PLUGIN=%s\n' "$HPLIP_VERSION"
      else
        INSTALL_PLUGIN_VERSION=$HPLIP_VERSION
      fi
    else
      INSTALL_PLUGIN_VERSION=$HPLIP_VERSION
    fi
  else
    echo 'HP Driver installed but HP_PLUGIN ENV not invoked'
  fi

  if [ ! -z "$INSTALL_PLUGIN_VERSION" ]; then
    printf 'Attempting to install plugin version %s\n' "$INSTALL_PLUGIN_VERSION"
    PLUGIN_FILE="/tmp/hplip-$INSTALL_PLUGIN_VERSION-plugin.run"

    if [ ! -f "$PLUGIN_FILE" ]; then
        echo 'Plugin does not already existing, downloading...'
        wget --backups 0 -P /tmp "https://developers.hp.com/sites/default/files/hplip-$INSTALL_PLUGIN_VERSION-plugin.run"
    fi
    chmod +x "$PLUGIN_FILE"
    yes | "$PLUGIN_FILE" --noprogress --accept --nox11 -- -i
    echo "Plugin installed!"
  fi
else
  echo 'HP driver not installed, no plugin check required.'
fi


node ./server/server.js
