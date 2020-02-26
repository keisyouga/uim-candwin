#!/usr/bin/tclsh

package require Tk

proc debug_print {msg} {
	global env
	if {[info exists env(ENABLE_DEBUG)]} {
		if $env(ENABLE_DEBUG) {
			puts -nonewline stderr $msg
		}
	}
}

################################################################
## global variables
# is_active
# candidate_index
# nr_candidates
# display_limit

wm withdraw .
tk useinputmethods 0
set listvar [list]
listbox .lbox -listvariable listvar

proc send_index {index} {
	global nr_candidates candidate_index
	if [expr $index < 0] { set index 0 }
	if [expr $index >= $nr_candidates] { set index [expr $nr_candidates - 1] }
	set msg "index\n$index\n\n"
	debug_print "send_index:$msg"
	puts stdout $msg

	set candidate_index $index
}

bind .lbox <<ListboxSelect>> {
	global candidate_index display_limit
	set cursel [.lbox curselection]
	set page [expr $candidate_index / $display_limit]
	debug_print "$cursel/$page\n"
	send_index [expr $page * $display_limit + $cursel]
}

button .btn< -text < -command {
	global candidate_index display_limit
	set i [expr $candidate_index - $display_limit]
	if [expr $i < 0] {
		set pos [expr $candidate_index % $display_limit]
		set lastpage [expr $nr_candidates / $display_limit]
		set i [expr $lastpage * $display_limit + $pos]
	}
	send_index $i
}
button .btn> -text > -command {
	global candidate_index display_limit
	set i [expr $candidate_index + $display_limit]
	set lastpage [expr $nr_candidates / $display_limit]
	if [expr $i >= [expr ($lastpage + 1) * $display_limit]] {
		set i [expr $candidate_index % $display_limit]
	}
	send_index $i
}
label .l -text 0/0
grid .lbox -row 0 -column 0 -columnspan 3
grid .btn< .l .btn> -row 1

wm attributes . -topmost
wm focusmodel . active

proc candwin_activate {msg} {
	global display_limit candidate_index nr_candidates is_active listvar
	set f1 [lindex $msg 1]
	set charset UTF-8
	if {[string equal -length 8 $f1 {charset=}]} {
		set charset [lindex [split $f1 =] 1]
	}

	set f2 [lindex $msg 1]
	set display_limit 0
	set i 2
	if {[string equal -length 14 $f2 {display_limit=}]} {
		set display_limit [lindex [split $f2 =] 1]
		set i 3
	}

	set tmp [lrange $msg $i end]
	set tmp2 "\{[join $tmp "\} \{"]\}"
	set listvar [string map {\a { }} $tmp2]

	set candidate_index -1
	set nr_candidates [llength $listvar]
	set is_active 1
	wm deiconify .
}
proc candwin_select {msg} {
	global candidate_index nr_candidates display_limit
	set candidate_index [lindex $msg 1]
	.l configure -text "[expr 1 + $candidate_index]/$nr_candidates"
	.lbox selection clear 0 $display_limit
	.lbox selection set [expr $candidate_index % $display_limit]
}
proc candwin_move {msg} {
	set x [lindex $msg 1]
	set y [lindex $msg 2]
	wm geometry . +$x+$y
}
proc candwin_show {msg} {
	global is_active
	if {$is_active} {
		wm deiconify .
	}
}
proc candwin_hide {msg} {
	wm withdraw .
}
proc candwin_deactivate {msg} {
	global is_active
	wm withdraw .
	set is_active 0
}
proc candwin_set_nr_candidates {msg} {
	global candidate_index nr_candidates display_limit is_active
	set candidate_index -1
	set nr_candidates [lindex $msg 1]
	.l configure -text "0/$nr_candidates"
	set display_limit [lindex $msg 2]
	set is_active 1
}
proc candwin_set_page_candidates {msg} {
	global listvar

	set f1 [lindex $msg 1]
	set charset UTF-8
	if {[string equal -length 8 $f1 {charset=}]} {
		set charset [lindex [split $f1 =] 1]
	}

	set f2 [lindex $msg 2]
	set page 0
	set i 2
	if {[string equal -length 5 $f2 {page=}]} {
		set page [lindex [split $f2 =] 1]
		set i 3
	}

	## use listvariable
	# a1 \a b1 \a c1 \f a2 \a b2 \a c2 \f ...
	#   => "a1 b1 c1" "a2 b2 c2" ...
	set tmp [lrange $msg $i end]
	set tmp2 "\"[join $tmp "\" \""]\""
	set listvar [string map {\a { }} $tmp2]
	debug_print "set_page_candidates:$listvar\n"
}
proc candwin_show_page {msg} {
	set page [lindex $msg 1]
	debug_print "candwin_show_page:$page\n"
	wm deiconify .
}
proc candwin_show_caret_state {msg} {}
proc candwin_update_caret_state {msg} {}
proc candwin_hide_caret_state {msg} {}

proc parse {msg} {
	debug_print "parse:$msg\n"

	# return if empty string
	if {[expr ! [string length $msg]]} {
		return
	}

	set fields [split $msg \f]
	set cmd [lindex $fields 0]

	switch -exact "$cmd" {
		activate { candwin_activate $fields }
		select { candwin_select $fields }
		move { candwin_move $fields }
		show { candwin_show $fields }
		hide { candwin_hide $fields }
		deactivate { candwin_deactivate $fields }
		set_nr_candidates { candwin_set_nr_candidates $fields }
		set_page_candidates { candwin_set_page_candidates $fields }
		show_page { candwin_show_page $fields }
		show_caret_state { candwin_show_caret_state $fields }
		update_caret_state { candwin_update_caret_state $fields }
		hide_caret_state { candwin_hide_caret_state $fields }
	}
}

proc read_cb {chan} {
	set data [read $chan]

	# eof?
    if {[eof $chan]} {
        #fileevent $chan readable {}
		exit
    }

	# escape "
	set data [string map { \" {\\\"} } $data]
	## split $data: msg1\f\fmsg2\f\f ... => "msg1" "msg2" "..."
	set msgs [string cat \"[string map { \f\f "\" \"" } $data]\"]
	debug_print "read_cb:<$msgs>\n"
	foreach msg $msgs {
		parse $msg
	}
}

set chan stdin
#fconfigure $chan -blocking 0 -encoding binary
fconfigure $chan -blocking 0
fileevent $chan readable [list read_cb $chan]
