#
# Main script
#
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
    set cb tuicb
    set done "#"
} else {
    set cb guicb
    mkgui
    wm protocol . WM_DELETE_WINDOW #
    set done "wm protocol . WM_DELETE_WINDOW exit"
}

# Command line...
if {[llength $argv] == 1} {
    main_run [lindex $argv 0] $cb
} elseif {[llength $argv] == 0} {
    set base "synctrue.ini"
    main_run [pick_ini $base [file normalize [file join [pwd] $base]]] $cb
} else {
    $cb progress main begin [llength $argv]
    set cnt 0
    foreach cfgfile $argv {
	$cb progress main [incr cnt]
	main_run $cfgfile $cb
    }
    $cb progress main end
}

eval $done



