set a {
    foreach item "$xml" {
	puts $item
    }

	switch -regexp -- $item {
	    "^#" {
		append res "{[lrange $item 0 end]} "
		#text item
	    }
	    "^/" {
		regexp {/(.+)} $item -> tagname ;# end tag
		set expected [lindex $stack end]
		if {$tagname!=$expected} {error "$item != $expected"}
		set stack [lrange $stack 0 end-1]
		append res "\}\} "
	    }
	    "/$" { # singleton - start and end in one <> group
		regexp {([^ ]+)( (.+))?/$} $item -> tagname - rest
		set rest [lrange [string map {= " "} $rest] 0 end]
		append res "{$tagname [list $rest] {}} "
	    }
	    default {
		set tagname [lindex $item 0] ;# start tag
		set rest [string map {= " "} $item]
		#set rest [lrange $rest  1 end]
		lappend stack $tagname
		append res "\{$tagname [list $rest] \{"
	    }
	}
	if {[llength $rest ]%2} {error "att's not paired: $rest"}
    }
    if [llength $stack] {error "unresolved: $stack"}
    string map {"\} \}" "\}\}"} [lindex $res 0]
}
