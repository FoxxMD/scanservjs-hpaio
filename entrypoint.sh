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

# assume user does not want to install plugin
PLUGIN="${PLUGIN_VERSION:=false}"
if [ "$PLUGIN" != "false" ]; then

  # determine installed HPLIP version
  RE="HP Linux Imaging and Printing System \(ver\. (.+?)\)"
  cmd_output=$(hp-plugin --help 2>&1)
  #https://stackoverflow.com/a/2778096
  HPLIP_VERSION="$(echo "$cmd_output" | sed -rn "s/$RE/\1/p")"
  printf 'HPLIP Version: %s\n' "HPLIP_VERSION"

  # if variable is true then try to determine plugin version automatically
  if [ "$PLUGIN" = "true" ]; then

    # check if plugin is already installed
    # files installed to these locations https://wiki.gentoo.org/wiki/HPLIP#Binary_plugins
    if [ -d /usr/share/hplip/data/firmware ]; then
      printf 'A plugin is already installed. To force (re)install specify version %s\n' "HPLIP_VERSION"
    else
      INSTALL_PLUGIN_VERSION=HPLIP_VERSION
    fi
  else
    INSTALL_PLUGIN_VERSION=HPLIP_VERSION
  fi
fi

if [ ! -z "$INSTALL_PLUGIN_VERSION" ]; then
  print 'Attempting to install plugin version %s\n' "INSTALL_PLUGIN_VERSION"
  wget -P /tmp
fi


node ./server/server.js
