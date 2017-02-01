#!/bin/sh /etc/rc.common
#
# Update the ADSL model forwarding rules
#
START=90
STOP=10
NAME=upnp

gw_url=""
cfgfile="/etc/upnp.conf"

warn() {
    echo "$@" 1>&2 
}

fatal() {
    warn "$@"
    exit 1
}

REM_TABLE=""
rpc() {
  local opts=""
  [ -n "$gw_url" ] && opts="-u $gw_url"
  upnpc $opts "$@"
}

remove_rule() {
    REM_TABLE="$REM_TABLE $*"
}
apply_removes() {
  [ -n "$REM_TABLE" ] && rpc -d $REM_TABLE
}

add_rule() {
  if [ -z "$local_ip" ] ; then
    warn "Unable to add rule, missing local_ip"
    return
  fi
  rpc -a $local_ip "$@"
}

validate_rule() {
  local myip="$1" proto="$2" ext="$3" rip="$4" int="$5"
  [ x"$myip" != x"$rip" ] && return 1
  local cint=$(port int $proto $ext)
  [ -z "$cint" ] && return 1

  local cport=$(port proto $proto $ext)
  [ -z "$cint" ] && return 1
  [ x"$cint" != x"$int" ] && return 1
  return 0
}

check_status() {
  local k ln
  while read k ln
  do
    case "$k" in
      "desc:")
	    gw_url="$ln"
	    ;;
      "Local")
	local_ip=$(echo "$ln" | tr -dc '.0-9')
	;;
      [0-9]*)
	    local proto=$(echo "$ln" | awk '{print $1}'|tr A-Z a-z)
	    local ext=$(echo "$ln" | tr '>:-' '   ' | awk '{print $2}')
	    local rip=$(echo "$ln" | tr '>:-' '   ' | awk '{print $3}')
	    local int=$(echo "$ln" | tr '>:-' '   ' | awk '{print $4}')
	    if validate_rule $local_ip $proto $ext $rip $int ; then
	      eval status_${proto}_${ext}=on
	    else
	      warn "Unknown REDIR: $proto $ext -> $rip:$int"
	      remove_rule $ext $proto
	    fi
	    ;;
    esac
  done
}

read_cfg() {
  local port ext int proto q="" v
  ports=""
  for port in $(sed -e 's/#.*$//' )
  do
    proto=$(echo "$port" | cut -d: -f1)
    ext=$(echo "$port" | cut -d: -f2)
    int=$(echo "$port" | cut -d: -f3)
    case "$proto" in
	tcp|TCP)
	    proto=tcp
	    ;;
	udp|UDP)
	    proto=udp
	    ;;
	*)
	    warn "Invalid protocol $port, ignoring"
	    continue
	    ;;
    esac

    for v in proto ext int
    do
      eval ${v}_${proto}_${ext}=\"\$$v\"
    done
    ports="$ports$q${proto}_${ext}"
    q=" "
  done
}

port() {
  if [ $# -eq 2 ] ; then
    eval echo \"\$${1}_${2}\"
  else
    eval echo \"\$${1}_${2}_${3}\"      
  fi
}

update_table() {
  local r
  for r in $ports
  do
    local status=$(port status $r)
    [ x"$status" = x"on" ] && continue # rule is already active
    echo $r : $status
    echo -n "Adding rule $r: "
    add_rule $(port int $r) $(port ext $r) $(port proto $r)
  done
}

######################################################################

start() {
  [ -f $cfgile ] || exit 1
  read_cfg <$cfgfile
  rpc -l |(
    exec 2>&1
    check_status
    apply_removes
    [ -n "$ports" ] && update_table
  ) | logger -t UPNPC
}
