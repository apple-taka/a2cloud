#! /bin/bash
# vim: set tabstop=4 shiftwidth=4 noexpandtab filetype=sh:

# ttyusbhandler.sh - a2cloud udev handler for USB serial devices (to be replaced)
#
# To the extent possible under law, T. Joseph Carter and Ivan Drucker have
# waived all copyright and related or neighboring rights to the a2cloud
# scripts themselves.  Software used or installed by these scripts is subject
# to other licenses.  This work is published from the United States.

# called by udev as:
# ttyusbhandler [add|remove] ttyUSBname

# depending on what port ttyUSB adapter was added or removed from,
# automatically launches or kills ADTPro as needed
# restarts getty as needed

# remove:
# kill any ADTPro for this port
# if a getty is on this port, do nothing here, it will be killed and respawn
#   iteself

# add:
# stagger adds by port number to prevent problems during simultaneous add at startup
# if lower port, solo adapter on lower port USB hub, or lower port of any USB hub,
#   kill any ADTPro, rescan for getty if sleeping, and launch adtPro
# if upper port, solo adapter on upper port USB hub, or higher port of any USB hub,
#   rescan for getty

if [[ $1 == "remove" ]]; then
	rm /tmp/udev-$2-removed &> /dev/null
	touch /tmp/udev-$2-removed
	pkill -f "$2.*ADTPro"
elif [[ $1 == "add" ]]; then
	[[ $2 == "ttyUSBlower" ]] && sleep 1.5
	[[ ${#2} -gt 11 ]] && sleep "${2:15:2}"
	if [[ $2 == "ttyUSBlower" || \
		$2 == $(ls -1 /dev/ttyUSBlower_hub* 2> /dev/null | head -1 | cut -c 6-) || \
		( ${2:0:12} == "ttyUSBlower_" && $2 != $(ls -1 /dev/ttyUSBupper_hub* 2> /dev/null | tail -1 | cut -c 6-) ) \
		]]; then
		rm /tmp/udev-ttyUSBlower-added &> /dev/null
		touch /tmp/udev-ttyUSBlower-added
		pkill -f "[A]DTPro"
		pkill -f "[u]sbgetty"
		exec echo "/usr/local/bin/adtpro.sh headless serial" | at -M now
	else # ttyUSBupper
		rm /tmp/udev-ttyUSBupper-added &> /dev/null
		touch /tmp/udev-ttyUSBupper-added
		pkill -f "[g]etty.*ttyUSB"
		if [[ -f /bin/systemctl ]]; then # if systemd
			# if USB-to-serial adapter is directly attached to upper port
			if [[ -c /dev/ttyUSBupper ]]; then
				ttyUSB=ttyUSBupper
			# if hub in upper port, use highest numbered port on hub
			elif [[ $(ls -1 /dev/ttyUSBupper_hub* 2> /dev/null | wc -l) -gt 0 ]]; then
				ttyUSB=$(ls -1 /dev/ttyUSBupper_hub* 2> /dev/null | tail -1 | cut -c 6-)
			# if hub in lower port with multiple adapters, use highest numbered port on hub
			elif [[ $(ls -1 /dev/ttyUSBlower_hub* 2> /dev/null | wc -l) -gt 1 ]]; then
				ttyUSB=$(ls -1 /dev/ttyUSBlower_hub* 2> /dev/null | tail -1 | cut -c 6-)
			else
			# by definition, this shouldn't happen
				ttyUSB=
			fi
			exec systemctl restart usbgetty@$ttyUSB
		fi
	fi
else
	exit 2
fi
