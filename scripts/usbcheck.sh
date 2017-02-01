#!/bin/sh /etc/rc.common
#
# Make sure that the external usb storage is mounted properly
#
START=99

counter=/root/counter
max_tries=3
canary=/data/v1/USB_DISK_NOT_PRESENT

start() {
  if [ -f $canary ] ; then
    # OK, external storage is missing
    cnt=0
    [ -f $counter ] && cnt=$(cat $counter)
    if [ $cnt -gt $max_tries ] ; then
      logger -t "USBCHK" "Unable to mount storage after $cnt reboots"
    else
      cnt=$(expr $cnt + 1)
      echo $cnt > $counter
      sync ; sync ; sync ; sleep 3
      reboot
    fi
  else
    [ -f $counter ] && rm $counter
  fi
}
