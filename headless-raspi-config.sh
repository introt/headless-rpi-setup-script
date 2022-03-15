#!/bin/bash

###########################################################################
#                                                                         #
#  headless-raspi-config.sh                                               #
#  Copyright (C) 2020-2021  introt (email domain: koti.fimnet.fi)         #
#                                                                         # 
#  This program is free software: you can redistribute it and/or modify   #
#  it under the terms of the GNU General Public License as published by   #
#  the Free Software Foundation, either version 3 of the License, or      #
#  (at your option) any later version.                                    #
#                                                                         #
#  This program is distributed in the hope that it will be useful,        #
#  but WITHOUT ANY WARRANTY; without even the implied warranty of         #
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the          #
#  GNU General Public License for more details.                           #
#                                                                         #
#  You should have received a copy of the GNU General Public License      #
#  along with this program.  If not, see <https://www.gnu.org/licenses/>. #
#                                                                         #
###########################################################################

# USER-EDITABLE PARTS
#
# VARS   - these you NEED to set
# STEPS  - comment out any you don't need

# For more informatino, please read the official documentation at
# https://www.raspberrypi.org/documentation/configuration/wireless/headless.md

# also this seems cool, haven't tried it though
# https://gist.github.com/leandrofilipe/7420c7bd0d24e0fdb144e8fe755492ee

# VARS - set these, then comment out unnecessary parts of STEPS
IMG="$HOME/Downloads/2021-05-07-raspios-buster-armhf-lite.img"
DISK="/dev/null" # for your safety
# p1 and p2 with sd card
BOOT="$DISK"1 # p1
ROOTFS="$DISK"2 # p2
MOUNT="$HOME/mnt" # I like working at home, feel free to take this outside
PRIV=/usr/bin/sudo # if you don't use sudo, change this and/or run as root
# wireless network settings
COUNTRY="FI" # two letter ISO 3166-1 country code
SSID='"example"' # keep the double quotes
PSK="22c4b41f857d22d452604ae0c9a01d2c9c2dd9a165ae5123f2b1ddb280d163cd" # generate with wpa_passphrase $SSID $password
# ssh key
KEY_TYPE="ed25519" # change to "rsa" if using some ancient version
KEY_BITS=4096 # ignored by ed25519
KEY_PASSPHRASE=''
COMMENT="$(whoami)@$(hostname)"
KEY_FILE="$HOME/.ssh/hrpi_rsa" # private key is generated, not used here; ".pub" is appended later

function execute_these_steps {
	# STEPS - comment out any unneeded ones
	#
	# You can also comment out the last line of this file
	# and run 'source raspi-headless-config.sh' to import
	# the functions into your shell for manual execution.
	
	# Optionally, you can put the above variables as well
	# as any functions you want to add/override with your
	# own into a file. I use this to keep my password out
	# of my git repo.

	# See "conf-example" for an example configuration file
	CONFIG_FILE="$HOME/.config/raspi"
	if [ -f "$CONFIG_FILE" ]; then
		echo "[] Sourcing variables from $CONFIG_FILE"
		source "$CONFIG_FILE"
	fi

	confirm_vars
	set -eu
	#nuke_disk # overwrites disk with zeroes (slow)
	write_img
	mk_mnt
	mount_disk
	enable_wifi
	enable_ssh
	generate_keys # you can skip this- just remember to point KEY_FILE to your existing key
	backup_default_sshd_config
	disable_passwd_auth
	authorize_key
	add_rootkit || true # this is a nominal joke (pun intended); the function is sourced from $CONFIG_FILE
	diff_sshd_config
	umount_disk
	clean_up

	# TODO: Unsolved problems, unimplemented solutions:

	# SSH host keys can be listed like so:
	#for f in "$MOUNT/rootfs"/etc/ssh/ssh_host_*_key; do "$PRIV" ssh-keygen -l -f "$f"; done
	# but are only generated after first boot
}

# FUNCTIONS - don't touch these, edit STEPS to disable

function press_enter {
	echo "Press Enter to continue..."
	read
}

function mk_mnt {
	echo "[] mkdir mnt/{boot,rootfs}"
	mkdir -p "$MOUNT"/{boot,rootfs}
}

function clean_up {
	echo "[] cleanup"
	rmdir "$MOUNT"/{{boot,rootfs},}
}

function confirm_vars {
	echo "[] Please confirm the vars are set correctly"
	echo "IMG	$IMG"
	echo "DISK	$DISK"
	echo "BOOT	$BOOT"
	echo "ROOTFS	$ROOTFS"
	echo "MOUNT	$MOUNT"
	echo ""
	echo "wifi"
	echo "COUNTRY	$COUNTRY"
	echo "SSID	$SSID"
	echo "PSK	$PSK"
	echo ""
	echo "ssh"
	echo "KEY_TYPE	$KEY_TYPE"
	echo "KEY_BITS	$KEY_BITS"
	echo "COMMENT 	$COMMENT"
	echo "KEY_FILE	$KEY_FILE"
	echo ""
	
	press_enter
}

function nuke_disk {
	echo "[] nuke $DISK"
	"$PRIV" dd if=/dev/zero of="$DISK" bs=1M status=progress conv=fsync
}

function write_img {
	echo "[] writing IMG to DISK"
	"$PRIV" dd if="$IMG" of="$DISK" bs=1M status=progress conv=fsync
	"$PRIV" sync
}

function mount_disk {
	echo "[] mount"
	"$PRIV" mount "$BOOT" "$MOUNT"/boot
	"$PRIV" mount "$ROOTFS" "$MOUNT"/rootfs
}

function umount_disk {
	echo "[] umount"
	"$PRIV" sync
	sleep 1
	"$PRIV" umount "$BOOT"
	"$PRIV" umount "$ROOTFS"
}

function enable_wifi {
	echo "[] create wpa_supplicant.conf"
	echo "ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
country=$COUNTRY
update_config=1

network={
  ssid=$SSID
  psk=$PSK
}" | "$PRIV" tee "$MOUNT"/boot/wpa_supplicant.conf
}

function enable_ssh {
	echo "[] enable ssh"
	"$PRIV" touch "$MOUNT"/boot/ssh
}

function generate_keys {
	echo "[] Generating SSH keys"
	ssh-keygen -t "$KEY_TYPE" -b "$KEY_BITS" -N "$KEY_PASSPHRASE" -C "$COMMENT" -f "$KEY_FILE"
}

function backup_default_sshd_config {
	"$PRIV" cp -v "$MOUNT"/rootfs/etc/ssh/sshd_config "$MOUNT"/rootfs/etc/ssh/sshd_config.old
}

function diff_sshd_config {
	if [ -f "$MOUNT/rootfs/etc/ssh/sshd_config.old" ]; then
		diff "$MOUNT/rootfs/etc/ssh/sshd_config" "$MOUNT/rootfs/etc/ssh/sshd_config.old" || true
	fi
}

function disable_passwd_auth {
	echo "[] Disable ssh passwd auth"
	"$PRIV" sed -e 's/#PasswordAuthentication yes/PasswordAuthentication no/' -i "$MOUNT/rootfs/etc/ssh/sshd_config"
}

function authorize_key {
	echo "[] Adding "$KEY_FILE".pub to authorized_keys"
	"$PRIV" mkdir "$MOUNT/rootfs/home/pi/.ssh"
	"$PRIV" cp "$KEY_FILE".pub "$MOUNT/rootfs/home/pi/.ssh/authorized_keys"
	"$PRIV" chown -R 1000:1000 "$MOUNT/rootfs/home/pi/.ssh"
	"$PRIV" chmod 700 "$MOUNT/rootfs/home/pi/.ssh"
	"$PRIV" chmod 600 "$MOUNT/rootfs/home/pi/.ssh/authorized_keys"
}

# If the script gets given a configuration file as an
# argument, it is sourced before executing anything;
# thus you can override the execute_these_steps
# function that determines which steps are run
if [ -f "$1" ]; then
	echo "[] Sourcing from $1"
	source "$1"
fi

# comment out the following line to not execute everything when sourcing
execute_these_steps
