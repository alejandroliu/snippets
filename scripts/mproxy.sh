#!/bin/sh
#
# The most basic proxy ever...
#
fail() {
  sed -e 's/$/\r/' <<-EOF
	HTTP/1.1 403 Forbidden
	Content-type: text/plain

	Not allowed
	$*
	EOF
  exit 1
}

read verb host_port proto
[ x"$verb" != x"CONNECT" ] && fail "Invalid method"
[ -n "$host_port" ] || fail "No host:port specified"
set - $(echo "$host_port" | tr ':' ' ')
[ $# -eq 2 ] || fail "Invalid host:port format"
target_host="$1"
target_port=$(echo "$2" | tr -dc 0-9)
[ -z "$target_host" ] && fail "Invalid host"
[ -z "$target_port" ] && fail "Invalid port"
[ x"$2" != x"$target_port" ] && fail "Invalid port syntax $2"


sed -e 's/$/\r/' <<-EOF
	HTTP/1.1 200 Tunnel established

	EOF

logger -t xproxy "$$: $target_host $target_port"

exec nc "$target_host" "$target_port"



