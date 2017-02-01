#!/bin/bash
#
#   Copyright (C) 2011 Alejandro Liu Ly
#
#   This is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as
#   published by the Free Software Foundation; either version 2 of 
#   the License, or (at your option) any later version.
#
#   This software is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public
#   License along with this program.  If not, see 
#   <http://www.gnu.org/licenses/>
#
#++
# NAME
#    fdistc 1
# SUMMARY
#    File distribution client
# SYNOPSIS
#    *fdistc* [options]
# DESCRIPTION
#    *fdistc* is used to keep a file distribution tree in sync with a
#    master web server.
# OPTIONS
#    * --url=URL
#      Web URL for the fdist repo.
#    * --maxtries=N
#      N is the number of retries before a download failes.
#    * --test
#      If specified only shows what commands will be executed.
#    * --verbose|-v
#      Show lots of diagnostic information
#    * --quiet|-q
#      Be silent
#    * --wget=wget_cmd
#      The wget command to use.
#    * --target=dir
#      Target directory where files are kepet
#    * --index=index
#      Used to keep local meta data to detect file changes.
# AUTHORS
#    Alejandro Liu Ly
# FILES
#    * /etc/fdistc
#      Default configuration variables
# SEE ALSO
#    *wget(1)*
#--


<?php include("core.sh"); ?>
<?php include("refs.sh"); ?>

[ -f /etc/fdistc ] && . /etc/fdistc

VERBOSE=-v
WGET_VERBOSE=-q
TARGET_DB=.fdist.idx
WGET="wget -O -"
DO=
MAXTRIES=4

while [ $# -gt 0 ]
do
  case "$1" in
    --url=*)
      FDIST_URL=${1#--url=}
      ;;
    --maxtries=*)
      MAXTRIES=${1#--maxtries=}
      ;;
    --test)
      DO=echo
      ;;
    --verbose|-v)
      VERBOSE=-v
      WGET_VERBOSE=-nv
      ;;
    --quiet|-q)
      VERBOSE=
      WGET_VERBOSE=-q
      ;;
    --wget=*)
      WGET=${1#--wget=}
      ;;
    --target=*)
      TARGET_DIR=${1#--target=}
      ;;
    --index=*)
      TARGET_DB=${1#--index=}
      ;;
    *)
      break
      ;;
  esac
  shift
done

for vv in FDIST_URL TARGET_DIR
do
  [ -z "$(get $vv)" ] && fatal "$vv not specified"
done

WGET="$WGET $WGET_VERBOSE"

dump_db() {
  (
    for VAR in ${!NSDB_*}
    do
      declare -p $VAR
    done
  ) | sed 's/^.*-- NSDB_/FSDB_/' > "$1"
}

db_upd() {
  local DB="$1"
  shift
  echo "$@" >> $DB
}

$WGET $FDIST_URL/.fdist.idx | (
  [ -f $TARGET_DIR/$TARGET_DB ] && . $TARGET_DIR/$TARGET_DB
  assign SEEN_$(mksym $TARGET_DB) 1
  COUNT=0

  while read M FNAME MD5 MODE F_UID F_GID SIZE MTIME
  do
    [ -z "$M" ] && continue
    [ x"$M" = x"ABORT" ] && fatal "fdist aborted:" \
	$FNAME $MD5 $MODE $F_UID $F_GID $SIZE $MTIME
    [ x"$M" != x"f" -a x"$M" != x"l" -a x"$M" != x"d" ] && continue

    DIR=$(dirname $FNAME)
    SYM=$(mksym $FNAME)
    assign SEEN_${SYM} 1

    F_DIR=$TARGET_DIR/$DIR
    F_PATH=$TARGET_DIR/$FNAME
    COUNT=$(expr $COUNT + 1)

    [ ! -d $F_DIR ] && $DO mkdir -p $VERBOSE $F_DIR
    if [ $M = "l" ] ; then
      # OK, this is a symlink...
      if [ -L $F_PATH ] ; then
	CLNK=$(readlink $F_PATH)
	[ $CLNK = $MD5 ] && continue
	$DO rm -f $VERBOSE $F_PATH
      fi
      if [ -e $F_PATH ] ; then
	# Not a symlink... remove it..
	$DO rm -rf $VERBOSE $F_PATH
      fi
      $DO ln $VERBOSE -s $MD5 $F_PATH
      continue
    fi
    if [ -L $F_PATH ] ; then
      # This shouldn't be a symlink!
      $DO rm -f $VERBOSE $F_PATH
    fi
    if [ $M = "d" ] ; then
      if [ ! -d $F_PATH ] ; then
	if [ -e $F_PATH ] ; then
	  $DO rm -f $VERBOSE $F_PATH
	fi
	$DO mkdir $VERBOSE $F_PATH
      fi
    elif [ $M = "f" ] ; then
      FETCH=yes
      if [ -f $F_PATH ] ; then
	# File exists...
	CMD5=$(get FSDB_MD5_${SYM})
	if [ x"$MD5" = x"$CMD5" -a $(stat -c '%s' $F_PATH) -eq $SIZE ] ; then
	  FETCH=no
	fi
      fi
      if [ $FETCH = yes ] ; then
	TMPFILE=$($DO mktemp -p $F_DIR)
	[ ! -f "$TMPFILE" ] && TMPFILE=$(mktemp)
	$DO chmod $MODE $TMPFILE # Keep things a bit less noisy
	trap "rm -f $TMPFILE" EXIT
	RETRIES=0
	while [ $RETRIES -lt $MAXTRIES ]
	do
	  $WGET $FDIST_URL/$FNAME > $TMPFILE
	  NMD5=$(md5sum $TMPFILE | (read a b ; echo $a))
	  [ x"$MD5" = x"$NMD5" -a $(stat -c '%s' $TMPFILE) -eq $SIZE ] && break
	  RETRIES=$(expr $RETRIES + 1)
	done

	if [ $RETRIES -eq $MAXTRIES ] ; then
	  warn "Unable to retieve $FNAME"
	  rm -f $TMPFILE
	  continue
	fi
	$DO mv $VERBOSE -f $TMPFILE $F_PATH
	rm -f $TMPFILE
	assign NSDB_MD5_${SYM} $NMD5
	$DO db_upd $TARGET_DIR/$TARGET_DB FSDB_MD5_${SYM}=$NMD5
      else
	assign NSDB_MD5_${SYM} $MD5
      fi
    fi
    if [ -e $F_PATH ] ; then
      if [ $UID -eq 0 ] ; then
	if [ $(find $F_PATH -maxdepth 0 -user $F_UID | wc -l) -eq 0 ] ; then
	  chown $VERBOSE $F_UID $F_PATH
	fi
	if [ $(find $F_PATH -maxdepth 0 -group $F_GID | wc -l) -eq 0 ] ; then
	  chgrp $VERBOSE $F_GID $F_PATH
	fi
      fi
      if [ $(find $F_PATH -maxdepth 0 -perm $MODE | wc -l) -eq 0 ] ; then
	chmod $VERBOSE $MODE $F_PATH
      fi
    fi
  done

  [ $COUNT -eq 0 ] && fatal "Empty manifest"

  $DO dump_db $TARGET_DIR/$TARGET_DB

  # OK... now we scan the tree to delete junk...
  find $TARGET_DIR -depth -mindepth 1 -printf '%P\n' | (
      while read F
      do
	SYM=$(mksym $F)
	[ -z "$(get SEEN_${SYM})" ] && $DO rm -rf $VERBOSE $TARGET_DIR/$F
      done
  )
)
