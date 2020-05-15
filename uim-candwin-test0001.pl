#!/usr/bin/perl

use strict;
use warnings;
use Tkx;

## debug message
sub debug_print {
	my ($msg) = @_;
	if ($ENV{ENABLE_DEBUG}) {
		print STDERR $msg;
	}
}

################################################################
## global variables
my $is_active = 0;
my $candidate_index;
my $nr_candidates;
my $display_limit;

## main window
my $top = undef;

## main windows position
my $topx;
my $topy;

## stores candidates list in current page
my @page_candidates;

## listbox widget used for display candidates
my $top_list = undef;

## label widget used for display position/number of candidates
my $top_label = undef;

## container for main window, hide it
my $mw = Tkx::widget->new(".");
$mw->g_wm_withdraw;

## do not use xim
## if use xim, when select item on listbox, uim-xim will get InputContext
## of tk-window's other than target-window's and crash.
Tkx::tk_useinputmethods(0);

## callback for event item selected in listbox
sub listboxselect_cb {
	my $listbox = shift;

	my $cursel = $listbox->curselection;
	# workaround; sometimes called without data
	if ($cursel !~ /^[0-9]+$/) {
		debug_print "<<ListboxSelect>>:$cursel\n";
		return;
	}
	# current page
	my $page = sprintf("%i", $candidate_index / $display_limit);
	send_index($page * $display_limit + $cursel);
}

sub create_listbox {
	my $parent = shift;
	my $list = $parent->new_listbox(-exportselection => 0);
	set_listbox($list, \@page_candidates);
	#$list->configure(-font => ['WenQuanYi Micro Hei Mono', 12]);
	$list->g_bind('<<ListboxSelect>>', [\&listboxselect_cb, $list]);
	return $list;
}

sub button_left_cb {
	my $i = $candidate_index - $display_limit;
	if ($i < 0) {
		my $pos = $candidate_index % $display_limit;
		my $lastpage = sprintf("%i", $nr_candidates / $display_limit);
		$i = $lastpage * $display_limit + $pos;
	}
	send_index($i);
}

sub create_label {
	my $parent = shift;
	## label: display candidate_index/nr_candidates
	my $label = $parent->new_label(-text => "0/0");
	return $label;
}

sub create_button_left {
	my $parent = shift;
	## < button
	my $btn_left = $parent->new_button(-text => "<",
	                                   -command => \&button_left_cb);
	return $btn_left;
}

sub button_right_cb {
	my $i = $candidate_index + $display_limit;
	my $lastpage = sprintf("%i", $nr_candidates / $display_limit);
	if ($i >= ($lastpage + 1) * $display_limit) {
		$i = $candidate_index % $display_limit;
	}
	send_index($i);
}

sub create_button_right {
	my $parent = shift;
	## > button
	my $btn_right = $parent->new_button(-text => ">",
	                                    -command => \&button_right_cb);
	return $btn_right;
}

# move_window(window, x, y)
sub move_window {
	my ($w, $x, $y) = @_;

	# adjust y position to fit screen
	my $screenh = $w->g_winfo_screenheight();
	my $winh = $w->g_winfo_reqheight();
	if ($y + $winh > $screenh) {
		$y = $y - $winh - 40; # above the caret
		if ($y < 0) {
			$y = 0;
		}
	}

	$w->g_wm_geometry(sprintf("+%i+%i", $x, $y));
}

## create candwin-window, listbox, label, button_left, button_right
sub create_window {
	if ($top) {
		$top->g_destroy;
	}
	if (!$is_active) {
		return;
	}
	$top = $mw->new_toplevel();
	$top->g_wm_withdraw();
	$top->g_wm_overrideredirect(1);
	#$top->g_wm_attributes(-type => "tooltip");
	#$top->g_wm_attributes(-topmost => 1); # always on top
	#$top->g_wm_focusmodel('active');      # do not focus window

	$top_list = create_listbox($top);
	$top_label = create_label($top);
	$top_label->configure(-text => 1 + $candidate_index . "/$nr_candidates");
	my $b1 = create_button_left($top);
	my $b2 = create_button_right($top);

	select_list();

	Tkx::grid($top_list, -row => 0, -column => 0, -columnspan => 3);
	Tkx::grid($b1, $top_label, $b2, -row => 1);

	# after create child-window, move window
	move_window($top, $topx, $topy);
	$top->g_wm_deiconify();
}

## send index message
sub send_index {
	my $index = shift;
	if ($index < 0) { $index = 0; }
	if ($index >= $nr_candidates) { $index = $nr_candidates - 1; }
	my $msg = sprintf("index\n%i\n\n", $index);
	debug_print "send_index:$msg";
	syswrite(STDOUT, $msg);
	##Tkx::puts($msg);            # alternative way
	##print STDOUT $msg; STDOUT->flush;     # alternative way 2

	$candidate_index = $index;
}

sub show_delay {
	Tkx::after(100, \&create_window);
}

## set listbox items
sub set_listbox {
	my $listbox = shift;
	my $cands = shift;

	$listbox->delete(0, 'end');
	map {
		$listbox->insert('end', $_);
	} @$cands;
}

## select listbox item, update label
sub select_list {
	$top_label->configure(-text => 1 + $candidate_index . "/$nr_candidates");
	$top_list->selection_clear(0, $display_limit);
	$top_list->selection_set($candidate_index % $display_limit);
}

################################################################
## handlers
sub candwin_activate {
	debug_print("candwin_activate\n");

	shift;                      # 'activate'
	my $charset = 'UTF-8';
	if ($_[0] =~ /^charset=(.*)/) {
		$charset = $1;
	}
	shift;                      # charset
	$display_limit = 0;
	if ($_[0] =~ /^display_limit=(.*)/) {
		$display_limit = $1;
		shift;                  # display_limit
	}

	@page_candidates = map {s/\a/ /gr} @_;
	if ($top) {
		set_listbox($top_list, \@page_candidates);
	}

	$candidate_index = -1;
	$nr_candidates = scalar @_;
	$is_active = 1;
	show_delay();
}
sub candwin_select {
	$candidate_index = $_[1];
	if ($top) {
		select_list();
	}
}
sub candwin_move {
	my ($cmd, $x, $y) = @_;
	debug_print "candwin_move $x, $y\n";
	$topx = $x;
	$topy = $y;
	if ($top) {
		move_window($top, $x, $y);
	}
}
sub candwin_show {
	if ($is_active) {
		show_delay();
	}
}
sub candwin_hide {
	if ($top) {
		$top->g_destroy();
		$top = undef;
	}
	# this is necessary because create_window will be called after hide
	$is_active = 0;
}
sub candwin_deactivate {
	if ($top) {
		$top->g_destroy();
		$top = undef;
	}
	$is_active = 0;
}
sub candwin_set_nr_candidates {
	$candidate_index = -1;
	$nr_candidates = $_[1];
	$display_limit = $_[2];

	if ($top) {
		$top_label->configure(-text => "0/$nr_candidates");
	}
	$is_active = 1;
}
sub candwin_set_page_candidates {
	shift;                      # command name
	#  if charset is specified
	my $charset = 'UTF-8';
	if ($_[0] =~ /^charset=(.*)/) {
		$charset = $1;
	}
	shift;                      # charset
	# if page is specified
	my $page = 0;
	if ($_[0] =~ /^page=(.*)/) {
		$page = $1;
		shift;                  # page
	}

	## set listbox variable
	@page_candidates = map {s/\a/ /gr} @_;
	if ($top) {
		set_listbox($top_list, \@page_candidates);
	}
}
sub candwin_show_page {
	my $page = $_[1];
	debug_print("candwin_show_page:$page\n");
	# TODO: what to do?

	show_delay();
}
sub candwin_show_caret_state {}
sub candwin_update_caret_state {}
sub candwin_hide_caret_state {}

## handle one message
sub parse {
	my ($msg) = @_;

	my @fields = split '\f', $msg;

	my $cmd = $fields[0];
	if ($cmd eq 'activate') {
		candwin_activate(@fields);
	} elsif ($cmd eq 'select') {
		candwin_select(@fields);
	} elsif ($cmd eq 'move') {
		candwin_move(@fields);
	} elsif ($cmd eq 'show') {
		candwin_show(@fields);
	} elsif ($cmd eq 'hide') {
		candwin_hide(@fields);
	} elsif ($cmd eq 'deactivate') {
		candwin_deactivate(@fields);
	} elsif ($cmd eq 'set_nr_candidates') {
		candwin_set_nr_candidates(@fields);
	} elsif ($cmd eq 'set_page_candidates') {
		candwin_set_page_candidates(@fields);
	} elsif ($cmd eq 'show_page') {
		candwin_show_page(@fields);
	} elsif ($cmd eq 'show_caret_state') {
		candwin_show_caret_state(@fields);
	} elsif ($cmd eq 'update_caret_state') {
		candwin_update_caret_state(@fields);
	} elsif ($cmd eq 'hide_caret_state') {
		candwin_hide_caret_state(@fields);
	}
}

## callback
sub read_cb {
	my ($fh) = @_;

	# read message
	my $n = sysread(STDIN, my $data, 8096);
	# eof?
	if ($n == 0) {
		#$interp->call('fileevent', 'stdin', readable => sub {});
		exit;
	}
	# sysread will error if binmode(STDIN, ':utf8')
	utf8::decode($data);
	my @msgs = split "\f\f", $data;
	my $i = 0;
	for (@msgs) {
		debug_print "read_cb:$i: $msgs[$i]\n";
		parse($msgs[$i]);
		$i++;
	}
}

## watch stdin
Tkx::fileevent('stdin', 'readable', [ \&read_cb, \*STDIN ]);

Tkx::MainLoop;
