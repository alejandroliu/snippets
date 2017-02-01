######################################################################
#
# TUI
#
######################################################################
set last [list]

proc tuiPrg {task cnt max} {
    if {$max == -1} {
	set pro "-\|/" 
	set pro [string index $pro [expr {$cnt % [string length $pro]}]]
	return [format "%s %d %s" $task $cnt $pro]
    } else {
	set lone [format "%s %d/%d " $task $cnt $max]
	set max [expr {70 - [string length $lone]}]
	if {$max < 10} {
	    return $lone
	}
    }
}

proc tuicb {args} {
    global last
    set cmd [lindex $args 0]
    set args [lrange $args 1 end]

    foreach {lmode ltask lerase} {{} {} {}} break
    foreach {lmode ltask lerase} $last break
    if {$lmode == "progress" && $cmd != "progress"} {
	puts -nonewline stderr "\r$lerase\r"
	set lerase {}
    }

    switch -- $cmd {
	iconify {
	    return
	}
	getDir {
	    # How to do this?
	    error "tui getDir un-implemented"
	}
	log {
	    global logmsg
	    lappend logmsg [join $args]

	    switch -- [lindex $args 0] {
		fatal -
		error {
		    puts stderr $args
		}
		warn -
		action -
		info {
		    puts stdout $args
		}
		debug {
		    global debug
		    if {$debug} {
			puts stdout $args
		    }
		}
	    }
	}
	progress {
	    global maxx

	    set ptask [lindex $args 0]
	    set opt [lindex $args 1]
	    set args [lrange $args 2 end]
	    
	    if {$lmode == "progress"} {
		if {$ptask == $ltask} {
		    puts -nonewline stderr "\r$lerase\r"
		} else {
		    puts stderr ""
		}
		set lerase {}
	    }

	    switch -- $opt {
		begin {
		    if {[llength $args]} {
			set maxx($ptask) [lindex $args 0]
			set line [tuiPrg $ptask 0 $maxx($ptask)]
		    } else {
			set line [tuiPrg $ptask 0 -1]
		    }
		}
		end {
		    set line {}
		}
		default {
		    if {[info exists maxx($ptask)]} {
			set line [tuiPrg $ptask $opt $maxx($ptask)]
		    } else {
			set line [tuiPrg $ptask $opt -1]
		    }
		}
	    }
	    set lerase [string repeat " " [string length $line]]
	    puts -nonewline stderr "$line"
	}
    }
    if {[info exists ptask]} {
	set ltask $ptask
    }
    set last [list $cmd $ltask $lerase]
}
