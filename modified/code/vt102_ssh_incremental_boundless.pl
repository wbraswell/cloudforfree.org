#!/usr/bin/perl
#
# Example script showing how to use Term::VT102 with an SSH command. SSHs to
# localhost and runs a shell, and dumps what Term::VT102 thinks should be on
# the screen.
#
# Logs all terminal output to STDERR if STDERR is redirected to a file.
#

use Term::VT102::Incremental;
use IO::Handle;
use POSIX ':sys_wait_h';
use IO::Pty;
use strict;



use Data::Dumper;







package Term::VT102::Incremental::Boundless;

use Moose;
use Term::VT102;
use Term::VT102::Boundless;
use Term::VT102::Incremental;

extends 'Term::VT102::Incremental';

use constant vt_class => 'Term::VT102::Boundless';

__PACKAGE__->meta->make_immutable;
no Moose;
 
1;

package main;



$| = 1;

#my $cmd = 'ssh -v -t localhost';
my $cmd = 'ssh localhost';

# Create the terminal object.
#



my $ROWS_MAX = 24;
my $COLUMNS_MAX = 80;
#my $vti = Term::VT102::Incremental->new (
my $vti = Term::VT102::Incremental::Boundless->new (
  'rows' => $ROWS_MAX,
  'cols' => $COLUMNS_MAX,
);
my $vt = $vti->vt;
my $vt_screen = [];
#my $vt_screen_clear = `clear`;




# Convert linefeeds to linefeed + carriage return.
#
$vt->option_set ('LFTOCRLF', 1);

# Make sure line wrapping is switched on.
#
$vt->option_set ('LINEWRAP', 1);

# Create a pty for the SSH command to run on.
#
my $pty = new IO::Pty;
my $tty_name = $pty->ttyname ();
if (not defined $tty_name) {
    die "Could not assign a pty";
}
$pty->autoflush ();

# Run the SSH command in a child process.
#
my $pid = fork;
if (not defined $pid) {
    die "Cannot fork: $!";
} elsif ($pid == 0) {
    #
    # Child process - set up stdin/out/err and run the command.
    #

    # Become process group leader.
    #
    if (not POSIX::setsid ()) {
        warn "Couldn't perform setsid: $!";
    }

    # Get details of the slave side of the pty.
    #
    my $tty = $pty->slave ();
    $tty_name = $tty->ttyname();

# Linux specific - commented out, we'll just use stty below.
#
#    # Set the window size - this may only work on Linux.
#    #
#    my $winsize = pack ('SSSS', $vt->rows, $vt->cols, 0, 0);
#    ioctl ($tty, &IO::Tty::Constant::TIOCSWINSZ, $winsize);

    # File descriptor shuffling - close the pty master, then close
    # stdin/out/err and reopen them to point to the pty slave.
    #
    close ($pty);
    close (STDIN);
    close (STDOUT);
    open (STDIN, "<&" . $tty->fileno ())
    || die "Couldn't reopen " . $tty_name . " for reading: $!";
    open (STDOUT, ">&" . $tty->fileno())
    || die "Couldn't reopen " . $tty_name . " for writing: $!";
    close (STDERR);
    open (STDERR, ">&" . $tty->fileno())
    || die "Couldn't redirect STDERR: $!";

    # Set sane terminal parameters.
    #
    system 'stty sane';

    # Set the terminal size with stty.
    #
    system 'stty rows ' . $vt->rows;
    system 'stty cols ' . $vt->cols;

    # Finally, run the command, and die if we can't.
    #
    exec $cmd;
    die "Cannot exec '$cmd': $!";
}

my ($cmdbuf, $stdinbuf, $iot, $eof, $prevxy, $died);

# IO::Handle for standard input - unbuffered.
#
$iot = new IO::Handle;
$iot->fdopen (fileno(STDIN), 'r');

# Removed - from Perl 5.8.0, setvbuf isn't available by default.
# $iot->setvbuf (undef, _IONBF, 0);

# Set up the callback for OUTPUT; this callback function simply sends
# whatever the Term::VT102 module wants to send back to the terminal and
# sends it to the child process - see its definition below.



$vt->callback_set ('OUTPUT', \&vt_output, $pty);



# Set up a callback for row changes, so we can process updates and display
# them without having to redraw the whole screen every time. We catch CLEAR,
# SCROLL_UP, and SCROLL_DOWN with another function that triggers a
# whole-screen repaint. You could process SCROLL_UP and SCROLL_DOWN more
# elegantly, but this is just an example.



my $changedrows = {};
#$vt->callback_set ('ROWCHANGE', \&vt_rowchange, $changedrows);
#$vt->callback_set ('CLEAR', \&vt_changeall, $changedrows);
#$vt->callback_set ('SCROLL_UP', \&vt_changeall, $changedrows);
#$vt->callback_set ('SCROLL_DOWN', \&vt_changeall, $changedrows);




# Set stdin's terminal to raw mode so we can pass all keypresses straight
# through immediately.
#
system 'stty raw -echo';

$eof = 0;
$prevxy = '';
$died = 0;

while (not $eof) {
    my ($rin, $win, $ein, $rout, $wout, $eout, $nr, $didout);

    ($rin, $win, $ein) = ('', '', '');
    vec ($rin, $pty->fileno, 1) = 1;
    vec ($rin, $iot->fileno, 1) = 1;

    select ($rout=$rin, $wout=$win, $eout=$ein, 1);

#    my $vt_updates = $vti->get_increment();
#    print {*STDERR} '<<<DEBUG>>>: have $vt_updates #2a = ', Dumper($vt_updates);

    # Read from the SSH command if there is anything coming in, and
    # pass any data on to the Term::VT102 object.
    #
    $cmdbuf = '';
    $nr = 0;
    if (vec ($rout, $pty->fileno, 1)) {
        $nr = $pty->sysread ($cmdbuf, 1024);
        $eof = 1 if ((defined $nr) && ($nr == 0));
        if ((defined $nr) && ($nr > 0)) {
            $vt->process ($cmdbuf);





            syswrite STDERR, $cmdbuf if (! -t STDERR);

#            my $vt_updates = $vti->get_increment();
#            print {*STDERR} '<<<DEBUG>>>: have $vt_updates #2c = ', Dumper($vt_updates);
        }
    }

    # End processing if we've gone 1 round after SSH died with no
    # output.
    #
    $eof = 1 if ($died && $cmdbuf eq '');

# Do your stuff here - use $vt->row_plaintext() to see what's on various
# rows of the screen, for instance, or before this main loop you could set
# up a ROWCHANGE callback which checks the changed row, or whatever.
#
# In this example, we just pass standard input to the SSH command, and we
# take the data coming back from SSH and pass it to the Term::VT102 object,
# and then we repeatedly dump the Term::VT102 screen.





#    $vt_updates = $vti->get_increment();
#    print {*STDERR} '<<<DEBUG>>>: have $vt_updates #3a = ', Dumper($vt_updates);





    # Read key presses from standard input and pass them to the command
    # running in the child process.
    #
    $stdinbuf = '';
    if (vec ($rout, $iot->fileno, 1)) {
        $nr = $iot->sysread ($stdinbuf, 16);
        $eof = 1 if ((defined $nr) && ($nr == 0));
        $pty->syswrite ($stdinbuf, $nr) if ((defined $nr) && ($nr > 0));
    }



#    $vt_updates = $vti->get_increment();
#    print {*STDERR} '<<<DEBUG>>>: have $vt_updates #3b = ', Dumper($vt_updates);



    # Dump what Term::VT102 thinks is on the screen. We only output rows
    # we know have changed, to avoid generating too much output.
    #
#    $didout = 0;
#    foreach my $row (sort keys %$changedrows) {
#        printf "\e[%dH%s\r", $row, $vt->row_sgrtext ($row);
#        delete $changedrows->{$row};
#        $didout ++;
#    }
#    if (($didout > 0) || ($prevxy ne ($vt->x . ',' . $vt->y))) {
#        printf "\e[%d;%dH", $vt->y, ($vt->x > $vt->cols ? $vt->cols : $vt->x);
#    }



# START HERE: merge sections below, enabled section can't scroll & misses lines when using $vt_updates for row number & doesn't color when using 2-del sprintf, disabled section doesn't color or handle arrow keys 
# START HERE: merge sections below, enabled section can't scroll & misses lines when using $vt_updates for row number & doesn't color when using 2-del sprintf, disabled section doesn't color or handle arrow keys 
# START HERE: merge sections below, enabled section can't scroll & misses lines when using $vt_updates for row number & doesn't color when using 2-del sprintf, disabled section doesn't color or handle arrow keys 


    $ROWS_MAX = $vt->rows;
    my $vt_screen_string = q{};
    my $vt_updates = $vti->get_increment();
#    print {*STDERR} '<<<DEBUG>>>: have $vt_updates #2b = ', Dumper($vt_updates);
    $didout = 0;
    foreach my $vt_update (@{$vt_updates}) {
        my $row_number = $vt_update->[0] + 1;
#    foreach my $row_number (0 .. $ROWS_MAX) {
#        print {*STDERR} '<<<DEBUG>>>: have $row_number = ', $row_number, "\n";
        my $column_number = $vt_update->[1] + 1;
#        my $column_diff = $vt_update->[2];
        my $column_diff_value = $vt_update->[2]->{v};
        $vt_screen_string .= sprintf "\e[%d;%dH%s", $row_number, $column_number, $column_diff_value;
#        my $vt_screen_string_row = $vt->row_sgrtext($row_number);
#        if (defined $vt_screen_string_row) {
#            $vt_screen_string .= sprintf "\e[%dH%s\r", $row_number, $vt->row_sgrtext($row_number);
#            $vt_screen_string .= sprintf "\e[%dH%s\r", $row_number, $vt_screen_string_row;
#            $didout ++;
#        }
    }
#    if (($didout > 0) || ($prevxy ne ($vt->x . ',' . $vt->y))) {
#        $vt_screen_string .= sprintf "\e[%d;%dH", $vt->y, ($vt->x > $vt->cols ? $vt->cols : $vt->x);
#    }
    print $vt_screen_string;



=DISABLE
            $ROWS_MAX = $vt->rows;
            $COLUMNS_MAX = $vt->cols;
            my $vt_updates = $vti->get_increment();
#            print {*STDERR} '<<<DEBUG>>>: have $vt_updates #2b = ', Dumper($vt_updates);
            foreach my $vt_update (@{$vt_updates}) {
                my $row_number = $vt_update->[0];
                my $column_number = $vt_update->[1];
                my $column_diff = $vt_update->[2];
                my $column_diff_value = $vt_update->[2]->{v};
                if (not ((exists $vt_screen->[$row_number]) and (defined $vt_screen->[$row_number]))) {
                    $vt_screen->[$row_number] = [];
                }
                $vt_screen->[$row_number]->[$column_number] = $column_diff_value;
            }
            my $vt_screen_string = q{};
            my $is_last_char = 0;
            for (my $row_number = 0; $row_number < $ROWS_MAX; $row_number++) {
                my $vt_screen_string_row = q{};
                my $is_last_row = ($row_number >= ($ROWS_MAX - 1));
                # create new rows to accept growing $ROWS_MAX
                if (not ((exists $vt_screen->[$row_number]) and (defined $vt_screen->[$row_number]))) {
                    $vt_screen->[$row_number] = [];
                }
                my $vt_screen_row = $vt_screen->[$row_number];
                for (my $column_number = 0; $column_number < $COLUMNS_MAX; $column_number++) {
                    # cursor placement, delete chars for unused columns in last row
                    if ($is_last_char or ($is_last_row and ((not defined $vt_screen_row->[$column_number]) or ((ord $vt_screen_row->[$column_number]) == 0)))) { 
                        $is_last_char = 1; 
#                        print {*STDERR} '<<<DEBUG>>>: found last char, deleting $row_number = ', $row_number, ', $column_number = ', $column_number, "\n";
                        delete $vt_screen_row->[$column_number];
                    }
                    # create new columns to accept growing $COLUMNS_MAX
                    elsif (not ((exists $vt_screen_row->[$column_number]) and (defined $vt_screen_row->[$column_number]))) { $vt_screen_row->[$column_number] = q{ }; }
                    # cursor placement, don't append deleted chars from unused columns
                    if (not $is_last_char) { $vt_screen_string_row .= $vt_screen_row->[$column_number]; }
                }
                # cursor placement, no newline in last row
                if ($row_number < ($ROWS_MAX - 1)) {
                    $vt_screen_string_row .= "\n";
                }
                $vt_screen_string .= $vt_screen_string_row;
            }
            `reset`;
            print $vt_screen_string;
=cut












#    $vt_updates = $vti->get_increment();
#    print {*STDERR} '<<<DEBUG>>>: have $vt_updates #3c = ', Dumper($vt_updates);



    # Make sure the child process has not died.
    #
    $died = 1 if (waitpid ($pid, &WNOHANG) > 0);
}

print "\e[24H\r\n";
$pty->close;

# Reset the terminal parameters.
#
system 'stty sane';


# Callback for OUTPUT events - for Term::VT102.
#
sub vt_output {
    my ($vtobject, $type, $arg1, $arg2, $private) = @_;

#    my $vt_updates = $vti->get_increment();
#    print {*STDERR} '<<<DEBUG>>>: have $vt_updates #4a = ', Dumper($vt_updates);

    if ($type eq 'OUTPUT') {
        $pty->syswrite ($arg1, length $arg1);
    }

#    $vt_updates = $vti->get_increment();
#    print {*STDERR} '<<<DEBUG>>>: have $vt_updates #4b = ', Dumper($vt_updates);
}


# Callback for ROWCHANGE events. This just sets a time value for the changed
# row using the private data as a hash reference - the time represents the
# earliest that row was changed since the last screen update.
#
sub vt_rowchange {
    my ($vtobject, $type, $arg1, $arg2, $private) = @_;
#$vt->callback_set ('ROWCHANGE', \&vt_rowchange, $changedrows);

#    my $vt_updates = $vti->get_increment();
#    print {*STDERR} '<<<DEBUG>>>: have $vt_updates #5a = ', Dumper($vt_updates);

    $private->{$arg1} = time if (not exists $private->{$arg1});

#    $vt_updates = $vti->get_increment();
#    print {*STDERR} '<<<DEBUG>>>: have $vt_updates #5b = ', Dumper($vt_updates);
}


# Callback to trigger a full-screen repaint.
#
sub vt_changeall {
    my ($vtobject, $type, $arg1, $arg2, $private) = @_;

#    my $vt_updates = $vti->get_increment();
#    print {*STDERR} '<<<DEBUG>>>: have $vt_updates #6a = ', Dumper($vt_updates);

    for (my $row = 1; $row <= $vtobject->rows; $row++) {
        $private->{$row} = 0;
    }

#    $vt_updates = $vti->get_increment();
#    print {*STDERR} '<<<DEBUG>>>: have $vt_updates #6b = ', Dumper($vt_updates);
}

# EOF
