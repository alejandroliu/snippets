#
# Main script
#
# Check if we are already running...
package require dde
if {[catch {dde execute TclEval [tk appname] 1} err]} {
    # OK, not running yet...
    dde servername [tk appname]
} else {
    dde execute TclEval [tk appname] {wm deiconify .}
    exit
}


set fw_dir [file dirname [info script]]

foreach src {ini.tcl prg.tcl synctrue.tcl syncgui.tcl synctui.tcl} {
    source [file join $fw_dir $src]
}

######################################################################
#
# Main entry points
#
######################################################################

if {[catch {tk appname} appname]} {
    error "Only GUI supported"
}

mkgui

wm withdraw .
#
# Main run try...
#
proc run_once {afterVal iniFile} {
    wm protocol . WM_DELETE_WINDOW "wm iconify ."
    guicb log info "Started [clock format [clock seconds]]"
    if {![winfo ismapped .]} {
	guicb iconify
    }
    main_run $iniFile guicb
    wm protocol . WM_DELETE_WINDOW "wm withdraw ."
    if {![winfo ismapped .]} {
	wm withdraw .
    }

    if {$afterVal} {
	after [expr {$afterVal * 1000}] [list run_once $afterVal $iniFile]
    }
}

proc main_bg {cfg} {
    if {![file exists $cfg]} {
	guicb log fatal "Missing $cfg file"
	return
    }
    set ini [ini::open $cfg r]
    set afterVal 3600	;# Re-sync every hour...
    if {[ini::exists $ini "General" "BgSecs"]} {
	set afterVal [::ini::value $ini "General" "BgSecs"]
    }
    ini::close $ini

    after [expr {$afterVal * 1000}] [list run_once $afterVal $cfg]
}

# Command line...
if {[llength $argv] == 1} {
    main_bg [lindex $argv 0]
} else {
    set base "synctrue.ini"
    main_bg [pick_ini $base [file normalize [file join [pwd] $base]]]
}
