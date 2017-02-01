#!/bin/sh
#
# Simple Bourne Shell script that implements an SysOp Shell
#
#
set -euf -o pipefail

VERSION=1.0
HOSTNAME=$(hostname -f 2>/dev/null || hostname)
exec 2>&1

## start-code
backup() {
  # 0. get lock
  # 1. check if snaps dont exist or exit
  # 2. check if external drive is connected or exit
  # 3. create snaps
  #    - lvcreate -Lsize -s -n lv1-snap /dev/vg1/lv1
  # 4. check if alvm2 is not running or stop it... wait for alvm2 to quit
  # 5. alvm2 launcher script
  # 6. wait for alvm2 to quit
  # 7. destrop snapshots
  #    - lvremove /dev/vg1/lv1-snap
  # 8. alvm2 launcher script
}
## end-code

echo "# sysop shell at $HOSTNAME"
while read cmd args
do
  case "$cmd" in
    quit)
      exit 0
      ;;
    version)
      echo "sos on $HOSTNAME version: $VERSION"
    backup)
      backup "$args"
      ;;
    *)
      echo "# Unknown command"
      ;;
  esac
done
