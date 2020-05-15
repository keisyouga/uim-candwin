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
# set is_active 0
# candidate_index
# nr_candidates
# display_limit
set top {}
# topx
# topy
# page_candidates
# top_list
# top_label

wm withdraw .
tk useinputmethods 0

proc listboxselect_cb {listbox} {
	global candidate_index display_limit
	set cursel [$listbox curselection]
	if {![string match {[0-9]*} $cursel]} {
		debug_print "<<ListboxSelect>>:$cursel\n"
		return
	}
	set page [expr $candidate_index / $display_limit]
	send_index [expr $page * $display_limit + $cursel]
}

proc create_listbox {parent} {
	global page_candidates
	set list [listbox $parent.lbox -exportselection 0]
	set_listbox $list $page_candidates
	bind $list  <<ListboxSelect>> "listboxselect_cb $list"
	return $list
}

proc button_left_cb {} {
	global candidate_index display_limit nr_candidates
	set i [expr $candidate_index - $display_limit]
	if {$i < 0} {
		set pos [expr $candidate_index % $display_limit]
		set lastpage [expr $nr_candidates / $display_limit]
		set i [expr $lastpage * $display_limit + $pos]
	}
	send_index $i
}

proc create_label {parent} {
	set label [label $parent.l -text "0/0"]
	return $label
}

proc create_button_left {parent} {
	set btn_left [button $parent.b_l -text "<" -command {button_left_cb}]
	return $btn_left
}

proc button_right_cb {} {
	global candidate_index display_limit nr_candidates
	set i [expr $candidate_index + $display_limit]
	set lastpage [expr $nr_candidates / $display_limit]
	if {$i >= ($lastpage + 1) * $display_limit} {
		set i [expr $candidate_index % $display_limit]
	}
	send_index $i
}

proc create_button_right {parent} {
	set btn_right [button $parent.b_r -text ">" -command {button_right_cb}]
	return $btn_right
}

proc move_window {w x y} {
	set screenh [winfo screenheight $w]
	set winh [winfo reqheight $w]
	if {$y + $winh > $screenh} {
		set y [expr $y - $winh - 40]
		if {$y < 0} {
			set y 0
		}
	}
	wm geometry $w "+$x+$y"
}

proc create_window {} {
	global top is_active top_list top_label topx topy
	global candidate_index nr_candidates
	if {$top ne {}} {
		destroy $top
	}
	if {!$is_active} {
		return
	}

	set top [toplevel .top]
	wm withdraw $top
	wm overrideredirect $top 1

	set top_list [create_listbox $top]
	set top_label [create_label $top]
	$top_label configure -text "[expr 1 + $candidate_index]/$nr_candidates"
	set b1 [create_button_left $top]
	set b2 [create_button_right $top]

	select_list

	grid $top_list -row 0 -column 0 -columnspan 3
	grid $b1 $top_label $b2 -row 1

	move_window $top $topx $topy
	wm deiconify $top
}

proc send_index {index} {
	global nr_candidates candidate_index
	if [expr $index < 0] { set index 0 }
	if [expr $index >= $nr_candidates] { set index [expr $nr_candidates - 1] }
	set msg "index\n$index\n\n"
	debug_print "send_index:$msg"
	puts stdout $msg

	set candidate_index $index
}

proc show_delay {} {
	after 100 {create_window}
}

proc set_listbox {listbox cands} {
	$listbox delete 0 end
	foreach e $cands {
		$listbox insert end $e
	}
}

proc select_list {} {
	global top_label top_list nr_candidates candidate_index display_limit
	$top_label configure -text "[expr 1 + $candidate_index]/$nr_candidates"
	$top_list selection clear 0 $display_limit
	$top_list selection set [expr $candidate_index % $display_limit]
}

proc candwin_activate {msg} {
	global display_limit candidate_index nr_candidates is_active
	global top top_list page_candidates
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
	set page_candidates {}
	foreach e $tmp {
		lappend page_candidates [string map {\a { }} $e]
	}
	if {$top ne {}} {
		set_listbox $top_list $page_candidates
	}

	set candidate_index -1
	set nr_candidates [llength $page_candidates]
	set is_active 1
	show_delay
}
proc candwin_select {msg} {
	global top candidate_index
	set candidate_index [lindex $msg 1]
	if {$top ne {}} {
		select_list
	}
}
proc candwin_move {msg} {
	global top topx topy
	set x [lindex $msg 1]
	set y [lindex $msg 2]
	set topx $x
	set topy $y
	if {$top ne {}} {
		move_window $top $x $y
	}
}
proc candwin_show {msg} {
	global is_active
	if {$is_active} {
		show_delay
	}
}
proc candwin_hide {msg} {
	global top is_active
	if {$top ne {}} {
		destroy $top
		set top {}
	}
	set is_active 0
}
proc candwin_deactivate {msg} {
	global top is_active
	if {$top ne {}} {
		destroy $top
		set top {}
	}
	set is_active 0
}
proc candwin_set_nr_candidates {msg} {
	global candidate_index nr_candidates display_limit is_active
	global top top_label
	set candidate_index -1
	set nr_candidates [lindex $msg 1]
	set display_limit [lindex $msg 2]

	if {$top ne {}} {
		$top_label configure -text "0/$nr_candidates"
	}
	set is_active 1
}
proc candwin_set_page_candidates {msg} {
	global page_candidates top top_list

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

	set tmp [lrange $msg $i end]
	set page_candidates {}
	foreach e $tmp {
		lappend page_candidates [string map {\a { }} $e]
	}
	if {$top ne {}} {
		set_listbox $top_list $page_candidates
	}
}
proc candwin_show_page {msg} {
	set page [lindex $msg 1]
	debug_print "candwin_show_page:$page\n"
	show_delay
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

	## split $data on \f\f into tcl list
	## $data: msg1\f\fmsg2\f\f ...
	set msgs [split [string map { \f\f \0 } $data] \0]
	debug_print "read_cb:<$msgs>\n"
	foreach msg $msgs {
		parse $msg
	}
}

set chan stdin
#fconfigure $chan -blocking 0 -encoding binary
fconfigure $chan -blocking 0
fileevent $chan readable [list read_cb $chan]
