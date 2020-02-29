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

## perl's list to tcl's list string
## FIXME: problem if string containing '{', '}'
sub tcl_list {
	my $cnames = ''; foreach my $i (@_) {$cnames = $cnames . ' {' . $i . '}';}
	return $cnames;
}

################################################################
## global variables
my $is_active = 0;
my $candidate_index;
my $nr_candidates;
my $display_limit;

## main window
my $top = Tkx::widget->new(".");

## hide window
$top->g_wm_withdraw;

## do not use xim
## if use xim, when select item on listbox, uim-xim will get InputContext
## of tk-window's other than target-window's and crash.
Tkx::tk_useinputmethods(0);
#Tkx::tk_useinputmethods(-display => '.', 0);

## create listbox
my $listvar;
my $lbox = $top->new_listbox(-listvariable => \$listvar, -exportselection => 0);
# specify font
#$lbox->configure(-font => ['WenQuanYi Micro Hei Mono', 12]);


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

## specify callback on listbox item select
$lbox->g_bind('<<ListboxSelect>>', sub {
	              my $cursel = $lbox->curselection;
	              # workaround; sometimes called without data
	              if ($cursel !~ /^[0-9]+$/) {
		              debug_print "<<ListboxSelect>>:$cursel\n";
		              return;
	              }
	              # current page
	              my $page = sprintf("%i", $candidate_index / $display_limit);
	              send_index($page * $display_limit + $cursel);
              });

## < button
my $btn_l = $top->new_button(-text => "<", -command => sub {
	                               my $i = $candidate_index - $display_limit;
	                               if ($i < 0) {
		                               my $pos = $candidate_index % $display_limit;
		                               my $lastpage = sprintf("%i", $nr_candidates / $display_limit);
		                               $i = $lastpage * $display_limit + $pos;
	                               }
	                               send_index($i);
                               });

## > button
my $btn_r = $top->new_button(-text => ">", -command => sub {
	                               my $i = $candidate_index + $display_limit;
	                               my $lastpage = sprintf("%i", $nr_candidates / $display_limit);
	                               if ($i >= ($lastpage + 1) * $display_limit) {
		                               $i = $candidate_index % $display_limit;
	                               }
	                               send_index($i);
                               });

## label: display candidate_index/nr_candidates
my $label = $top->new_label(-text => "0/0");

Tkx::grid($lbox, -row => 0, -column => 0, -columnspan => 3);
Tkx::grid($btn_l, $label, $btn_r, -row => 1);

## always on top
$top->g_wm_attributes(-topmost => 1);

## do not focus window
$top->g_wm_focusmodel('active');

## remove titlebar (problem; this ignores topmost)
# $top->g_wm_overrideredirect(1);
# $top->g_wm_attributes(-type => "tooltip");

sub show_delay {
	Tkx::after(100, sub {$top->g_wm_deiconify if ($is_active);});
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

	#$listvar = tcl_list(map {s/\a/ /gr;} @_);
	$listvar = Tkx::list(map {s/\a/ /gr;} @_);
	debug_print $listvar;

	$candidate_index = -1;
	$nr_candidates = scalar @_;
	$is_active = 1;
	show_delay();
}
sub candwin_select {
	$candidate_index = $_[1];
	$label->configure(-text => 1 + $candidate_index . "/$nr_candidates");
	$lbox->selection_clear(0, $display_limit);
	$lbox->selection_set($candidate_index % $display_limit);
}
sub candwin_move {
	my ($cmd, $x, $y) = @_;
	debug_print "candwin_move $x, $y\n";
	$top->g_wm_geometry("+$_[1]+$_[2]");
	# todo: adjust position to fit screen
}
sub candwin_show {
	if ($is_active) {
		show_delay();
	}
}
sub candwin_hide {
	$top->g_wm_withdraw;
}
sub candwin_deactivate {
	$top->g_wm_withdraw;
	$is_active = 0;
}
sub candwin_set_nr_candidates {
	$candidate_index = -1;
	$nr_candidates = $_[1];

	$label->configure(-text => "0/$nr_candidates");
	$display_limit = $_[2];
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
	# escape " { }
	#my @tmp = map { $_ =~ s/["{}]/\\$&/gr; } @_;
	#$listvar = tcl_list(map {s/\a/ /gr;} @tmp);
	# Tkx::list works fine
	$listvar = Tkx::list(map {s/\a/ /gr;} @_);
	debug_print "$listvar\n";
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
