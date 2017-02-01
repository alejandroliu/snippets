#!/bin/sh /etc/rc.common
# Copyright (C) 2006-2011 OpenWrt.org

START=50
syslog_path="<?= $syslog_path ?>"

start() {
	[ -f /etc/syslog-ng/syslog-ng.conf ] || return 1
	uptime=$(sed 's/\..*//' /proc/uptime)
	# echo $uptime >/tmp/uptime.txt
	bootfile=/tmp/bootmsgs.txt
	[ $uptime -lt 600 ] && logread > $bootfile
	service_start /usr/sbin/syslog-ng
	if [ -f $bootfile ] ; then
	  timeout=0
	  while [ $(netstat -lnt 2>/dev/null | grep ':514 ' | wc -l) -ne 1 ]
	  do
	    sleep 1
	    timeout=$(expr $timeout + 1)
	    [ $timeout -gt 60 ] && break
	  done
	  sleep 3
	  nc localhost 514 < $bootfile
	  rm -f $bootfile
	fi
	if [ -n "$syslog_path" ] ; then
	  if [ -f "$syslog_path" ] ; then
	    [ -L /var/log/messages ] || ln -s "$syslog_path" /var/log/messages
	  fi
	fi
}

stop() {
	service_stop /usr/sbin/syslog-ng
}

reload() {
	service_reload /usr/sbin/syslog-ng
}
