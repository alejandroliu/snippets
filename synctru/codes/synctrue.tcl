#!/usr/bin/tclsh
#
proc lshift listVar {
    upvar 1 $listVar l
    set r [lindex $l 0]
    set l [lreplace $l [set l 0] 0]
    return $r
}

proc check_file {name path queue_r} {
    upvar $queue_r queue

    file stat $path st
    set mode [format "%04o" [expr {$st(mode) & 07777}]]
    switch -exact -- $st(type) {
	file {
	    return [list \
			"f" \
			$name \
			$mode \
			$st(mtime) \
			$st(size)]
	}
	directory {
	    lappend queue $name
	    return [list \
			"d" \
			$name \
			$mode]
	}
	link {
	    return [list \
			"l" \
			- \
			[file readlink $path]]
	}
    }
    return {}
}

proc genfsdb {db root} {
    set queue [list {}]
    set results [list]
    while {[llength $queue]} {
	set dir [lshift queue]
	foreach f [glob -dir [file join $root $dir] -nocomplain -tails -- *] {
	    puts "root=$root"
	    puts "dir=$dir"
	    puts "f=$f"
	    puts "name [file join $dir $f]"
	    puts "path [file join $root $dir $f]"
	    set res [check_file \
			 [file join $dir $f] \
			 [file join $root $dir $f] \
			 queue ]
	    if {$res != {}} { lappend results $res }
	}
    }
    return $res
}
puts [genfsdb {} toc]

