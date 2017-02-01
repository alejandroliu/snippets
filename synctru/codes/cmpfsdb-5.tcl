#!/usr/bin/tclsh
#
# My license for the code: Use it (commercial or non-commercial), learn
# from it, modify it, give me credit in source form, and don't blame me
# at all for any damage.
#
#'''cmpfsdb-5.tcl:'''
# Copyright 2006 George Peter Staplin
# Revision 5
# May 31, 2006 fixed a DELETED NEW pattern with proc filter.invalid.  

array set ::records {}
array set ::changes {}

proc read.records id {
    global records
    
    #
    # Read 500 chars, unless that would exceed the amount remaining.
    #
    set amount 500
    
    if {$amount > $records($id,remaining)} {
	set amount $records($id,remaining)
    }
    
    #
    # Concatenate the partial record (if there was one) with the new data.
    #
    set data [split $records($id,partial)[read $id $amount] \n]
    #puts DATA:$data
    
    #
    #XXX check for [eof $id] just in case the db is changed by another program?
    #
    
    #
    # Recalculate the remaining data.
    #
    set records($id,remaining) [expr {$records($id,remaining) - $amount}]
    
    #
    # Set the valid records (terminated by \n) in the records array.
    #
    set records($id,records) [lrange $data 0 [expr {[llength $data] - 2}]]
    
    #puts RECORDS:$records($id,records)
    
    #
    # There may be a partial record at the very end, so save that for use later.
    #
    set records($id,partial) [lindex $data end]
    
    #puts PARTIAL:$records($id,partial)
    
    set records($id,offset) [tell $id]
}

proc init.record {id f} {
    global records
    
    set records($id,file) $f
    set records($id,fd) $id
    set records($id,offset) 0
    set records($id,size) [file size $f]
    set records($id,remaining) $records($id,size)
    set records($id,partial) ""
    set records($id,records) [list]
    
    read.records $id
}

proc compare.records {a b} {
    foreach {a_ctime a_mtime a_f} $a break
    foreach {b_ctime b_mtime b_f} $b break
    
    global changes
    
    if {$a_f eq $b_f} {
	if {$a_ctime != $b_ctime} {
	    lappend changes($a_f) CTIME
	}
	
	if {$a_mtime != $b_mtime} {
	    lappend changes($a_f) MTIME
	}
	return 0
    } else {
	#puts "a_f $a_f"
	#puts "b_f $b_f"
	return [string compare $a_f $b_f]
    }
}

proc next.record id {
    global records
    
    if {![llength $records($id,records)]} {
	#
	# We need to attempt to read more records, because the list is empty.
	#
	if {$records($id,remaining) <= 0} {
	    #
	    # This record database has reached the end.
	    #
	    return [list]
	}
	read.records $id
    }
    
    set r [lindex $records($id,records) 0]
    set records($id,records) [lrange $records($id,records) 1 end]
    
    #puts REC:$r
    
    return $r
}

proc compare.databases {a b} {
    global records changes
    
    set ar [next.record $a]
    set br [next.record $b]
    
    while {[llength $ar] && [llength $br]} {
	set a_f [lindex $ar 2]
	set b_f [lindex $br 2]
	
	#puts "CMP $a_f $b_f"
	
	switch -- [compare.records $ar $br] {
	    -1 {
		#
		# $a_f < $b_f in character value
		# $a_f was deleted
		#
		lappend changes($a_f) DELETED
		set ar [next.record $a]
	    }
	    
	    0 {
		set ar [next.record $a]
		set br [next.record $b]
	    }
	    
	    1 {
		#
		# $a_f > $b_f in character value
		# Therefore the file $b_f is a new file.
		# XXX is this always right?  It seems like it should be, because
		# the other operations go a record at a time, and the values are pre-sorted.
		#
		#puts NEW
		lappend changes($b_f) NEW
		set br [next.record $b]
	    }
	}
    }
    
    #puts AR:$ar
    #puts BR:$br
    
    #
    # One or both of the lists are exhausted now. 
    # We must see which it is, and then list the files
    # remaining as NEW or DELETED.
    #
    if {![llength $ar]} {
	#
	# We have a remaining file unhandled by the loop above.
	#
	if {[llength $br]} {
	    lappend changes([lindex $br 2]) NEW
	}
	
	#
	# The files remaining are new in the 2nd database/b.
	#
	while {[llength [set br [next.record $b]]]} {
	    lappend changes([lindex $br 2]) NEW
	}  
    }
    
    if {![llength $br]} {
	#
	# This record wasn't handled by the loop above.
	#
	if {[llength $ar]} {
	    lappend changes([lindex $ar 2]) DELETED
	}
	
	#
	# The files remaining were deleted from the 2nd database/b.
	#
	while {[llength [set ar [next.record $a]]]} {
	    lappend changes([lindex $ar 2]) DELETED
	}
    }
}


proc filter.invalid ar_var {
    upvar $ar_var ar
    
    foreach {key value} [array get ar] {
	if {[set a [lsearch -exact $value DELETED]] >= 0 \
		&& [lsearch -exact $value NEW] >= 0} {
	    
	    set value [lreplace $value $a $a]
	    set b [lsearch -exact $value NEW]
	    set value [lreplace $value $b $b]
	    
	    if {![llength $value]} {
		unset ar($key)
		continue
	    }
	    set ar($key) $value
	}
    }
}

proc main {argc argv} {
    if {2 != $argc} {
	puts stderr "syntax is: [info script] database-1 database-2"
	return 1
    }
    
    foreach {f1 f2} $argv break
    
    set id1 [open $f1 r]
    set id2 [open $f2 r]
    
    init.record $id1 $f1
    init.record $id2 $f2
    
    compare.databases $id1 $id2
    
    filter.invalid ::changes
    
    parray ::changes
    
    return 0
}
exit [main $::argc $::argv]
}
