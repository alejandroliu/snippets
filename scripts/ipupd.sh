#!/bin/sh /etc/rc.common
#
# Simple script to update afraid.org record
#
START=90
STOP=10
NAME=ipupd

RUN_D=/var/run
PID_F=$RUN_D/${NAME}.pid
STATE_D=/var/state
STATE_F=$STATE_D/${NAME}.state

fatal() {
    echo "$@" 1>&2
    exit 1
}

get_my_ip() {
    wget -q -O- http://0ink.net/adm/redir.php
}

rpc() {
  local apiurl="$1"
  local apikey="$2"
  local action="$3"
  shift 3 || return 1
  if [ $# -gt 0 ] ; then
    local code="&$(echo $* | tr ' ' '&')"
  else
    local code=""
  fi
  wget -q -O- "$apiurl?action=$action&sha=$apikey$code"
}


logmsg() {
  logger -p local3.info -t IPUPD: -- "$@"
}

ipupd_daemon() {
  local apiurl="$1"
  local apikey="$2"
  local check="$3"

  logmsg "Starting ${NAME} daemon"

  while :
  do
    if ipaddr=$(get_my_ip) ; then
      if values=$(rpc $apiurl $apikey getdyndns) ; then
	for each in $values
	do
	  domain=$(echo "$each" | cut -d'|' -f1)
	  dns_ip=$(echo "$each" | cut -d'|' -f2)
	  update_url=$(echo "$each" | cut -d'|' -f3)

	  if [ x"$ipaddr" != x"$dns_ip" ] ; then
	    logmsg "Updating $domain: $(wget -O- "$update_url" )"
	  fi
	done
      fi
    fi
    sleep $check
  done
}

stop() {
  # service_kill ${NAME} $PID_F
  [ -f $PID_F ] && kill -1 $(cat $PID_F)
}

start() {
    local apiurl apikey check

    mkdir -p $RUN_D $STATE_D
    config_load ${NAME}
    config_get apiurl config apiurl
    config_get apikey config apikey

    [ -z "$apikey" ] && fatal "No apikey specified"
    [ -z "$apiurl" ] && fatal "No apiurl specified"
    config_get check config sleep_time 3600

    (
      # Daemonise...
      MYPID=$(sh -c 'echo "$PPID"')
      [ -z "$MYPID" ] && fatal "Unable to determine PID of subshell"
      exec >/dev/null 2>&1 </dev/null
      echo $MYPID > $PID_F
      cat $PID_F
      ipupd_daemon "$apiurl" "$apikey" "$check"
    ) &
}

if [ x"$0" != x"/etc/rc.common" ] ; then
  logmsg() {
    echo "$@"
  }
  check=3600
  while [ $# != 0 ] ; do
    case "$1" in 
      --check=*)
        check=${1#--check=}
	;;
      --apikey=*)
        apikey=${1#--apikey=}
        ;;
      --apiurl=*)
        apiurl=${1#--apiurl=}
        ;;
      *)
        domain="$1"
    esac
    shift
  done
  [ -z "$apiurl" -o -z "$apikey" ] \
      && fatal "Missing API credentials"
  ipupd_daemon "$apiurl" "$apikey" "$check" 
fi
