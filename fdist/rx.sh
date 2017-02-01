#!/bin/sh
export PATH=$PATH:/usr/local/bin:/usr/local/sbin:/sbin:/usr/sbin

<?php
require_once("ashlib/core.sh");
require_once("ashlib/fixfile.sh");
?>

OFFLINE=no
SAVEOUT=

[ -f /etc/tlcfg ] && . /etc/tlcfg

# FDIST stuff
FDIST_TARGET=/pkgs
RX_PATH=/fdist/bin/rx
RX=$FDIST_TARGET$RX_PATH
FDIST_PATH=/fdist/bin/fdistc
FDIST=$FDIST_TARGET$FDIST_PATH

while [ $# -gt 0 ] 
do
  case "$1" in
    --offline)
      OFFLINE=yes
      shift
      ;;
    --online)
      OFFLINE=no
      shift
      ;;
    --save=*)
      SAVEOUT=${1#--save=}
      shift
      ;;
    *)
      break
      ;;
  esac
done


if [ $OFFLINE = no ] ; then
  # Make sure we have network
  (ifconfig | grep -q eth ) || dhclient -H `hostname` eth0

  RM_FDIST=:
  if [ ! -x $FDIST ] ; then
    FDIST=$(mktemp)
    RM_FDIST="rm -f $FDIST"
    trap "$RM_FDIST" EXIT
    wget -nv -O $FDIST $CFGURL/$CFGVER/fdist.php/tlbox$FDIST_PATH \
	|| fatal "Can not bootstrap FDIST"
    chmod a+x $FDIST
  fi

  PREV_RX=$([ -f $RX ] && md5sum $RX | awk '{print $1}')

  if [ -d $FDIST_TARGET ] ; then
    [ -w $FDIST_TARGET ] || fatal "$FDIST_TARGET: read-only"
  fi
  $FDIST --repo=tlbox --target=$FDIST_TARGET
  NEXT_RX=$(md5sum $RX | awk '{print $1}')
  $RM_FDIST

  ### Make sure RX script was not changed
  if [ x"$PREV_RX" != x"$NEXT_RX" ] ; then
    echo "RX updated, restarting..."
    exec $RX "$@"
  fi

  # We now make sure that commands are linked in...
  LNPKG=$(find /pkgs -name lnpkg | head -1)
  [ -z "$LNPKG" ] && fatal "lnpkg: not found"
  [ -x "$LNPKG" ] || fatal "$LNPKG is not executable"

  $LNPKG -v do clean
  for TLPKG in $FDIST_TARGET/*/
  do
    # Check if it is already installed
    if $LNPKG --source $TLPKG info ; then
      # Yes... update it
     $LNPKG --source $TLPKG do update
    else
      # Nope we install
      echo "LNPKG ADD $TLPKG"
      $LNPKG --source $TLPKG do create
    fi
  done
fi

if [ -f /etc/php.ini ] ; then
  # Make sure we enable short open tags...
  fixfile --filter /etc/php.ini <<-'EOF'
	sed -e 's/^short_open_tag = .*$/short_open_tag = On/'
	EOF
fi

ACTION="$1"
shift || fatal "No action specified"

if [ -z "$SAVEOUT" ] ; then
  exec rx-$ACTION "$@"
  fatal "$ACTION: not recognised"
fi

type rx-$ACTION || fatal "ACTION not recognised"
ASHCC=/pkgs/post/lib/post/scripts/ashcc

$ASHCC $([ x"$SAVEOUT" != x"-" ] && echo -o$SAVEOUT) $(which rx-$ACTION)


