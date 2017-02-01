#!/bin/sh /etc/rc.common
#
# Simple script to start/stop heyu services
#
START=90
STOP=10
NAME=x10d

EXTRA_COMMANDS="cron"
EXTRA_HELP="	cron - run cron tasks"

stop() {
  heyu stop
}

start() {
  heyu start
  heyu upload
}

cron() {
  heyu upload
}
