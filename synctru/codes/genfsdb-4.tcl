#!/usr/bin/tclsh
#
# My license for the code: Use it (commercial or non-commercial), learn
# from it, modify it, give me credit in source form, and don't blame me
# at all for any damage.
#
# genfsdb-4.tcl:
# Copyright 2006 George Peter Staplin

proc generate.file.system.database {db root} {
    proc out data "[list puts [set fd [open $db w]]] \$data"
    recurse $root
    close $fd
}

proc recurse {dir} {
    foreach f [lsort -dictionary [glob -nocomplain [file join $dir *]]] {
	#puts FILE:$f
	if {![file exists $f]} {
	    #
	    # The file is a symbolic link that doesn't point to anything.
	    #
	    continue
	}

	file stat $f stats
	#
	# It's critical that we use list here, because the filename
	# may have spaces.
	#
	out [list $stats(ctime) $stats(mtime) $f]
	if {[file isdirectory $f]} {
	    #
	    # XXX we could use a trampoline here to eliminate the recursion
	    # The wiki has an example for such a trampoline by RS.
	    # XXX in unix we also have the issue of symbolic links.
	    # We need a circular link test to make this complete.
	    #
	    recurse $f
	}
    }
}

proc main {argc argv} {
    if {2 != $argc} {
	puts stderr "syntax is: [info script] database filesystem-root"
	return 1
    }
    generate.file.system.database [lindex $argv 0] [lindex $argv 1]
    return 0
}
exit [main $::argc $::argv]
