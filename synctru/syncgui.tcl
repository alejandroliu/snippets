######################################################################
#
# GUI CODE
#
######################################################################
set logmsg [list]

proc guicb {args} {
    set cmd [lindex $args 0]
    set args [lrange $args 1 end]
    
    switch -- $cmd {
	deiconify {
	    if {![winfo ismapped .]} {
		wm deiconify .
	    }
	    return
	}
	iconify {
	    wm iconify .
	    return
	}
	getDir {
	    return [eval tk_chooseDirectory $args]
	}
	log {
	    global logmsg
	    lappend logmsg [join $args]

	    set cur [.f.lb index end]
	    global debug
	    if {[lindex $args 0] != "debug"  || $debug} {
		.f.lb insert end [lrange $args 1 end]
		.s configure -text [lrange $args 1 end]
	    }
	    switch -- [lindex $args 0] {
		fatal {
		    guicb deiconify
		    .f.lb itemconfigure $cur -foreground white -background red
		    tk_messageBox \
			-icon error \
			-title [mc "synctrue Error"] \
			-message $args \
			-type ok
		}
		error {
		    guicb deiconify
		    .f.lb itemconfigure $cur -foreground red
		}
		warn {
		    guicb deiconify
		    .f.lb itemconfigure $cur -foreground yellow -background navy
		}
		action {
		    guicb deiconify
		    .f.lb itemconfigure $cur -foreground black
		}
		info {
		    .f.lb itemconfigure $cur -foreground navy
		}
		debug {
		    if {$debug} {
			.f.lb itemconfigure $cur -foreground green
		    }
		}
	    }
	    .f.lb see $cur
	}
	progress {
	    global maxx
	    set ptask [lindex $args 0]
	    set opt [lindex $args 1]
	    set args [lrange $args 2 end]
	    
	    switch -- $opt {
		begin {
		    if {[llength $args]} {
			set maxx($ptask) [lindex $args 0]
		    }
		    Progress .mf.$ptask
		    pack .mf.$ptask \
			-side top -fill both -expand -1 -padx 30 -pady 10
		    SetProgress .mf.$ptask 0 1

		    .s configure -text $ptask
		}
		end {
		    catch { unset maxx($ptask) }
		    destroy .mf.$ptask
		    .s configure -text {}
		}
		default {
		    if {[info exists maxx($ptask)]} {
			SetProgress .mf.$ptask $opt $maxx($ptask)
			.s configure -text "$ptask: ($opt/$maxx($ptask)) $args"
		    } else {
			set num [expr {$opt % 20}]
			if {$num >= 10} {
			    SetProgress .mf.$ptask [expr {20-$num}] 9
			} else {
			    SetProgress .mf.$ptask $num 9
			}
			variable dkfprogress::progressPercent
			set dkfprogress::progressPercent(.mf.$ptask) $ptask
			.s configure -text "$ptask: ($opt)  $args"
		    }
		}
	    }
	}
    }
    update
}


proc ctrlk {} {
  console show
}

proc mkgui {} {
    option add "*Button.font" "Helvetica 8 bold" widgetDefault
    frame .mf
    pack .mf -side top -fill both -expand 1

    frame .f
    pack .f -side top -fill both -expand 1 -padx 5

    scrollbar .f.sb -command {.f.lb yview}
    pack .f.sb -side right -fill y -expand 1
    listbox .f.lb -width 64 -height 12 -exportselection 0 \
	-yscrollcommand {.f.sb set}
    pack .f.lb -side left -fill both -expand 1

    label .s -text {} -relief sunken -border 2 -anchor w \
	-width [.f.lb cget -width]
    pack .s -side top -fill x -expand 1 -padx 5 -pady 3


    # pack .b -side top -pady 10

    bind . <Control-Key-k> ctrlk

    foreach line {
	"Starting SYNCTRUE"
	"Copyright (C) 2009 Alejandro Liu Ly"
	"All Rights Reserved."
	""
    } {
	set pos [.f.lb index end]
	.f.lb insert end $line
    }
    .f.lb see $pos

    wm resizable . 0 0
}


