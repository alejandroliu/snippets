set debug 1
package require msgcat
namespace import msgcat::mc

######################################################################
#
# THIS BLOCK CONTAINS SYNC-TRUE WORKING STUFF
#
######################################################################
proc nOp {args} { }

#****f* filedata
# SUMMARY
#    Used to read file meta data
# USAGE
proc filedata {filepath fname} {
    # DESCRIPTION
    #	 Retrieve meta data from a given file
    # INPUTS
    #	 * fpath - full path to retrieve meta data
    #	 * fname - relative path
    # OUTPUTS
    #	 returns a list of name/value pairs usable for array set
    #****
    array set meta {}

    set meta(mtime) [file mtime $filepath]
    # Note we do this because FAT limitations
    if {$meta(mtime) % 2} {
	incr meta(mtime)
    }
    set meta(size) [file size $filepath]
    set meta(name) $fname
    return [array get meta]
}


#****f* prunedirs
# SUMMARY
#    Prune empty directories
# USAGE
proc prunedirs {rdir {subdir {}} {cb nOp}} {
    # DESCRIPTION
    #	 Scan a directory tree deleteing empty directories
    # INPUTS
    #	 * rdir - Root of directory we are scanning
    #	 * subdir - Subdirectory we are currently scanning
    #    * cb - callback -- report status
    # OUTPUTS
    #	 number of entries in the sub directory
    #****
    global pruneKnt

    if {$subdir == ""} {
	$cb progress prunedirs begin
	set pruneKnt 0
    } else {
	$cb progress prunedirs [incr pruneKnt] $subdir
    }

    set cnt 0
    foreach f [glob -nocomplain -tails -directory [file join $rdir $subdir] *] {
	set fpath [file join $rdir $subdir $f]
	set fname [file join $subdir $f]

	switch -- [file type $fpath] {
	    directory {
		set cnt [expr {$cnt + [prunedirs $rdir $fname $cb]}]
	    }
	    default {
		incr cnt
	    }
	}
    }
    if {$subdir == ""} {
	$cb progress prunedirs end
	unset pruneKnt
    } elseif {$cnt == 0} {
	$cb log action RMDIR [file join $rdir $subdir]
	file delete [file join $rdir $subdir]
    }
    return $cnt
}


#****f* scandir
# SUMMARY
#    Scan directory contents
# USAGE
proc scandir {rdir dat_r {subdir {}} {cb nOp}} {
    # DESCRIPTION
    #	 Scan recursively the contents of a directory updating the data array
    # INPUTS
    #	 * rdir - Root of directory we are scanning
    #	 * dat_r - reference to array that receives data
    #	 * subdir - Subdirectory we are currently scanning
    #    * cb - callback -- report status
    # OUTPUTS
    #	 dat_r is updated
    #****
    upvar $dat_r dat

    global scandirKnt
    if {$subdir == ""} {
	$cb progress scandir begin
	set scandirKnt 0
    } else {
	$cb progress scandir [incr scandirKnt] $subdir
    }

    foreach f [glob -nocomplain -tails -directory [file join $rdir $subdir] *] {
	if {[fsfilter $f]} continue

	set fpath [file join $rdir $subdir $f]
	set fname [file join $subdir $f]
	set fid [string tolower $fname]

	switch -- [file type $fpath] {
	    file {
		set dat($fid) [filedata $fpath $fname]
	    }
	    directory {
		scandir $rdir dat $fname $cb
	    }
	    #characterSpecial, blockSpecial, fifo, link, or socket.
	    default {
		$cb log warn $fname unsupported type [file type $fpath]
	    }
	}
    }
    if {$subdir == ""} {
	$cb progress scandir end
	unset scandirKnt
    }
}

#****f* arraywrite
# SUMMARY
#    Write an array
# USAGE
proc arraywrite {dat_r fd} {
    # INPUTS
    #	 * dat_r - reference to output array
    #	 * fd - file id
    # OUTPUTS
    #	 text is send on fd
    #****
    upvar $dat_r dat

    foreach {key val} [array get dat] {
	puts $fd [list $key $val]
    }
}

#****f* arrayread
# SUMMARY
#    Read an array
# USAGE
proc arrayread {dat_r fd} {
    # INPUTS
    #	 * dat_r - reference to input array
    #	 * fd - file id
    #****
    upvar $dat_r dat

    catch {unset dat}
    while {![eof $fd]} {
	set key {}
	set val {}
	foreach {key val} [gets $fd] break
	# lassign [gets $fd] key val
	if {$key == "" && $val == ""} continue
	set dat($key) $val
    }
}

#****f* fswrite
# SUMMARY
#    write a fs meta data file
# USAGE
proc fswrite {dat_r fname} {
    # INPUTS
    #    * dat_r - reference to output array
    #    * fname - fname to write data to
    #****
    upvar $dat_r dat

    set fd [open $fname w] 
    puts $fd [clock seconds] ;# We use to detect TZ changes...
    arraywrite dat $fd
    close $fd
}

#****f* fsread
# SUMMARY
#    read from fs meta data file
# USAGE
proc fsread {dat_r fname} {
    # INPUTS
    #    * dat_r - reference to output array
    #    * fname - fname to read data from
    #****
    upvar $dat_r dat

    set fd [open $fname r]
    set fctime [gets $fd] ;# We use to detect TZ changes...
    set fstime [file mtime $fname]

    if {abs($fctime - $fstime) > 1800} {
	set adj [expr {int(($fstime - $fctime)/1800.0+0.5)}]
	puts stderr "ADJ: $adj"
    } else {
	set adj 0
    }

    arrayread dat $fd
    close $fd

    if {$adj} {
	# Do the TZ adjustment...
	foreach k [array names dat] {
	    array set tm $dat($k)
	    set tm(mtime) [expr {$tm(mtime) - $adj}]
	    set dat($k) [array get tm]
	}
    }
}

#***f* chk_path
# SUMMARY
#    Make sure the path to the file exists
# USAGE
proc chk_path {rdir fpath} {
    # INPUTS
    #    rdir - src dir path
    #    fpath - file path
    #****
    file mkdir [file dirname [file join $rdir $fpath]]
}


#***f* docopy
# SUMMARY
#    Copy from one side  to the other
# USAGE
proc docopy {srcdir dstdir fsname meta_r {cb nOp}} {
    # DESCRIPTION
    #    If the file exists, move from one side to the other
    #    If it doesn't it will delete it from target.
    #    Meta is updated
    # INPUTS
    #    srcdir - source directory
    #    dstdir - destination directory
    #    fsname - file path
    #    meta_r - reference to meta data array
    #    cb - reporting callback
    # OUTPUT
    #    meta data is updated
    #-
    upvar $meta_r meta
    set src [file join $srcdir $fsname]
    set dst [file join $dstdir $fsname]
    set fid [string tolower $fsname]

    if {[file exists $src]} {
	$cb log action copying $fsname "($srcdir->$dstdir)"

	array set finfo [set meta($fid) [filedata $src $fsname]]

	file copy -force -- $src $dst
	file mtime $dst $finfo(mtime)
	# No need to adjust $src (even though there is no exact match...)
    } else {
	# Source was actually deleted
	if {[file exists $dst]} {
	    $cb log action deleting $fsname "($dstdir)"
	    catch {unset meta($fid)}
	    file delete -- $dst
	}
    }
}

#***f* make_backup
# SUMMARY
#    Create backup copies of a file
# USAGE
proc make_backup {dpath fpath {cb nOp}} {
    # DESCRIPTION
    #    Create backup copies of files following certain naming
    #    conventions
    # INPUTS
    #    dpath - dir path
    #    fpath - file path
    #****
    set fname [file join $dpath $fpath]
    if {![file exists $fname]} return

    set name [file tail $fname]
    set dir [file dirname $fname]
    set ext [file extension $name]
    set name [file rootname $name]

    set v 0
    set backup [format ".bk-%s%s" $name $ext]
    while {[file exists [file join $dir $backup]]} {
	set backup [format ".bk-%s%d%s" $name [incr v] $ext]
    }
    $cb log action backup $fpath $backup "($dpath)"
    file rename $fname [file join $dir $backup]
}
#


#***f* applychg
# SUMMARY
#    Apply changes to trees
# USAGE
proc applychg {workdir repodir chglist_r metadat_r {cb nOp}} {
    # DESCRIPTION
    #    Run to the change list and apply the changes to
    #    directories.
    # INPUTS
    #    workdir - work directory (target for send)
    #    rerpodir - repo directory (target for recv)
    #    chglist_r - reference to change list array
    #    metadat_r - reference to meta data array
    #	 cb - reporting call back
    #-
    upvar $chglist_r chgs
    upvar $metadat_r meta

    $cb progress applychg begin [llength [array names chgs]]
    set cnt 0

    foreach fname [array names chgs] {
	foreach {op fsname} $chgs($fname) break
	$cb progress applychg [incr cnt] $fsname
	if {[catch {
	    switch -exact -- $op {
		send {
		    chk_path $workdir $fsname
		    docopy $repodir $workdir $fsname meta $cb
		}
		sendback {
		    chk_path $workdir $fsname
		    make_backup $workdir $fsname $cb
		    docopy $repodir $workdir $fsname meta $cb
		}
		recv {
		    chk_path $repodir $fname
		    docopy $workdir $repodir $fsname meta $cb
		}
		default {
		    error "Internal error"
		}
	    }
	} err]} {
	    $cb log error [list logerr applychg $fname $err]
	}
    }
    $cb progress applychg end
}

#***f* chkchanged
# SUMMARY
#    Compare size and time stamp and determine changes
# USAGE
proc chkchanged {set1 set2} {
    # DESCRIPTION
    #    Checks mtime and size and returns true if they differ, false
    #    if they match
    # INPUTS
    #    set1 - key/value pairs for first file
    #	 set2 - key/value pairs for second file
    # OUTPUTS
    #	  true if they differ, false if they match
    #****
    array set ar1 $set1
    array set ar2 $set2

    if {[expr {$ar1(mtime) != $ar2(mtime) || $ar1(size) != $ar2(size)}]} {
	return 1
    } else {
	return 0
    }
}

#***f* attr
# SUMMARY
#    Get an attribute from an array set/get
# USAGE
proc attr {kvdata key} {
    # DESCRIPTION
    #    Retrieves the value matching the pair from a list made of key/value
    #    pairs
    # INPUTS
    #    kvdata - list with key/value pairs
    #    key - what we want to lookup
    # OUTPUTS
    #    found vlaue
    #-
    array set dat $kvdata
    return $dat($key)
}


#***f* resolvchg
# SUMMARY
#    Scan file systems for changes
# USAGE
proc resolvchg {mark curmeta_r snapmeta_r chgs_r conflict {cb nOp}} {
    # DESCRIPTION
    #	Scans Compares current metadata with metadata snapshot and
    #	determines changes.
    # INPUTS
    #   mark - how to identify this change
    #   curmeta_r - reference to current meta data
    #	snapmeta_r - reference to snapshot meta data
    #   chgs_r - reference to array that receives changes
    #   conflict - how we identify conflicting changes
    #	cb - status call back
    # OUTPUTS
    #	chgs_r is updates
    #****
    upvar $curmeta_r cur
    upvar $snapmeta_r snap
    upvar $chgs_r chgs

    # Check for modified files
    $cb progress resolvchg1 begin [llength [array names cur]]
    set cnt 0
    foreach fname [array names cur] {
	$cb progress resolvchg1 [incr cnt] $fname
	set fsname [attr $cur($fname) name]

	if {![info exists snap($fname)]} {
	    # This is a new file!
	    if {[info exists chgs($fname)]} {
		set chgs($fname) [list $conflict $fsname]	;# Conflict!
	    } else {
		set chgs($fname) [list $mark $fsname]
	    }
	} elseif {[chkchanged $cur($fname) $snap($fname)]} {
	    # This is a modified file!
	    if {[info exists chgs($fname)]} {
		set chgs($fname) [list $conflict $fsname]	;# Conflict!
	    } else {
		set chgs($fname) [list $mark $fsname]
	    }
	}
    }
    $cb progress resolvchg1 end

    # Check for deleted files
    $cb progress resolvchg2 begin [llength [array names snap]]
    set cnt 0
    foreach fname [array names snap] {
	$cb progress resolvchg2 [incr cnt] $fname
	set fsname [attr $snap($fname) name]

	if {![info exists cur($fname)]} {
	    # This one was deleted
	    if {![info exists chgs($fname)]} {
		set chgs($fname) [list $mark $fsname]
	    }
	    # For deletion, conflicts are ignored
	}
    }
    $cb progress resolvchg2 end
}


#***f* syncdir
# SUMMARY
#    Synchronise directories
# USAGE
proc syncdir {workdir repodir metafile {cb nOp}} {
    # DESCRIPTION
    #    Does the necessary work for synchronising
    # INPUTS
    #    workdir - Usually this is the area that users work on files
    #    repodir - the _master_ copy that multiple users sync with
    #    metafile - meta file in the workdir used to track changes
    #****
    $cb progress syncdir begin 100

    $cb progress syncdir 5 "Read meta file"
    if {[file exists $metafile]} {
	fsread metadat $metafile
    } else {
	array set metadat {}
    }
    $cb progress syncdir 10 "scan work tree"
    scandir $workdir workdat {} $cb
    $cb progress syncdir 30 "scan repo tree"
    scandir $repodir repodat {} $cb
    array set chglst {}

    $cb progress syncdir 40 "Resolve changes 1"
    resolvchg "send" repodat metadat chglst "?error?" $cb
    $cb progress syncdir 50 "Resolve changes 2"
    resolvchg "recv" workdat metadat chglst "sendback" $cb

    $cb progress syncdir 60 "apply chgs"
    applychg $workdir $repodir chglst metadat $cb
    $cb progress syncdir 70 "Write meta data file"
    fswrite metadat $metafile

    $cb progress syncdir 80 "Prune dirs $workdir"
    prunedirs $workdir {} $cb
    $cb progress syncdir 90 "Prune dirs $repodir"
    prunedirs $repodir {} $cb

    $cb progress syncdir end
}



######################################################################
#
# Configure environment
#
######################################################################

#****f* fsync/inicfg
# SUMMARY
#    Initialise configuration file
# USAGE
proc inicfg {cfgfile cb} {
    # DESCRIPTION
    #	 Reads configuration file and if necessary configures things properly
    # INPUTS
    #	 cfgfile - location of configuration file
    #    cb - used for dialogs
    # OUTPUTS
    #	 returns a INI file handle
    #****
    set cfgfile [file normalize $cfgfile]

    if {![file exists $cfgfile]} {
	set ini [ini::open $cfgfile w]
	ini::close $ini
    }
    set ini [ini::open $cfgfile r]
    if {[ini::exists $ini "General" "Repository"] &&
		[ini::exists $ini "Local" [info hostname]]} {
	# We found minimum configuration requirements
	return $ini
    }
    # We are not fully configured...
    ini::close $ini
    set ini [ini::open $cfgfile r+]

    # Missing configuration items... so we ask user for them...
    set commit 0

    # General repository
    if {![ini::exists $ini "General" "Repository"]} {
	set matchme "[file dirname $cfgfile]/"
	regsub -- {/+$} $matchme "/" matchme
	set matchlen [expr {[string length $matchme]-1}]
	set xtxt [mc "Select repository location"]
	set txt ""
	while {1} {
	    set dir [$cb getDir \
		-initialdir [file dirname $cfgfile] \
		-title "$xtxt\n$txt" \
		-mustexist 0]
	    if {$dir eq ""} {
		error [mc "No repository directory specified"]
	    }
	    # Check if directory is valid
	    if {[string range $dir 0 $matchlen] eq $matchme} break
	    set txt [mc "Repository must be a subdirectory"]
	}
	set dir [string range $dir [expr {$matchlen + 1}] end]

	file mkdir [file join [file dirname $cfgfile] $dir]

	ini::set $ini "General" "Repository" $dir
	set commit 1
    }

    # Identify local repository location...
    if {![ini::exists $ini "Local" [info hostname]]} {
	set dir [$cb getDir \
		-title [mc "Select local copy directory"] \
		-mustexist 0]
	if {$dir eq ""} {
	    error [mc "No local directory specified"]
	}
	file mkdir $dir
	ini::set $ini "Local" [info hostname] $dir
	set commit 1
    }

    # We save and reopen again...
    if {$commit} { ini::commit $ini }
    ini::close $ini

    return [ini::open $cfgfile r]
}

######################################################################
#
# Main entry point
#
######################################################################

proc main_run {cfgfile cb} {
    $cb log info "Reading configuration file $cfgfile"

    if {[catch {inicfg $cfgfile $cb} ini]} {
	$cb log fatal "[mc "Error reading INI $cfgfile"]: $ini"
	return
    }

    #
    # Create Filter function if any
    #
    if {[::ini::exists $ini filters]} {
	set fsfilter {
	    if {[_fsfilter $name]} {return 1}
	}
	foreach {re modeline} [::ini::get $ini filters] {
	    set mode [lindex $modeline 0]
	    set args [lrange $modeline 1 end]
	    if {"exclude"  == $mode} {
		append fsfilter \
		    "\nif {\[regexp $args -- {$re} \$name\]} { return 1}\n" 
	    } elseif {"include" == $mode} {
		append fsfilter \
		    "\nif {\[regexp $args -- {$re} \$name\]} { return 0}\n" 
	    }
	}
	append fsfilter "\n	return 0\n"
	proc fsfilter name $fsfilter
    }
    set repodir [file join [file dirname $cfgfile] [ini::value $ini "General" "Repository"]]
    set workdir [ini::value $ini "Local" [info hostname]]
    ini::close $ini

    $cb log info "    Repo fs: $repodir"
    $cb log info "    Work fs: $workdir"

    set metafile "${workdir}-meta.txt"

    syncdir $workdir $repodir $metafile $cb

    $cb log info "Done $repodir <-> $workdir"
}

######################################################################
proc _fsfilter {name} { 
    set name [string tolower $name]
    foreach pattern {".bk-*"  "*~"} {
	if {[string match -nocase $pattern $name]} { return 1 }
    }
    return 0
}
proc fsfilter {name}  {
    return [_fsfilter $name]
}

#
proc get_volumes {} {
    global tcl_platform

    if {$tcl_platform(platform) eq "unix"} {
	# When in Unix, this is less than satisfactory...
	if {[file exists "/proc/mounts"]} {
	    # We revert to this one... works on Linux
	    set vols [list]
	    set fd [open "/proc/mounts" r]
	    while {![eof $fd]} {
		lappend vols [lindex [split [gets $fd] " "] 1]
	    }
	    close $fd
	    return [lsort -unique $vols]
	}
	# else, we could parse the output of DF
    }
    # This is the default... tested to work on Windows
    return [file volumes]
}

proc pick_ini {base {default {}}} {
    foreach {dir} [get_volumes] {
	if {$dir eq ""} continue
	if {[file exists [file join $dir $base]]} {
	    return [file normalize [file join $dir $base]]
	}
    }
    return $default
}



