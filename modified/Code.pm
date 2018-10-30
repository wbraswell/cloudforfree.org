# [[[ PREPROCESSOR ]]]
# <<< TYPE_CHECKING: OFF >>>

# [[[ HEADER ]]]
#use RPerl;  # scans CGI* & Catalyst* etc, lots of delay & warnings
package ShinyCMS::Controller::Code;
use strict;
use warnings;
use RPerl::AfterSubclass;
our $VERSION = 0.020_000;

=head1 NAME

ShinyCMS::Controller::Code

=head1 DESCRIPTION

Controller for ShinyCMS source code tools.

=cut

# [[[ OO INHERITANCE ]]]
use Moose;
use MooseX::Types::Moose qw/ Int /;
use namespace::autoclean;
BEGIN { extends 'ShinyCMS::Controller'; }
# NEED FIX: remove Moose, replace w/ RPerl OO below
#use parent qw(ShinyCMS::Controller);
#use ShinyCMS::Controller;

# [[[ CRITICS ]]]
# NEED FIX: what actual critics are needed here?
## no critic qw(ProhibitUselessNoCritic ProhibitMagicNumbers RequireCheckedSyscalls)  # USER DEFAULT 1: allow numeric values & print operator
## no critic qw(RequireInterpolationOfMetachars)  # USER DEFAULT 2: allow single-quoted control characters & sigils

# [[[ INCLUDES ]]]
use File::Temp qw(tempfile);
use IPC::Run3 qw(run3);
#use IPC::Open3;  # replaced by IO::Pty::Easy below
#use IO::Pty::Easy;  # replaced by Tie::File below
use Tie::File;
use IO::Select;
use CGI qw(params);
use CGI::Ajax;
use Symbol qw(gensym); 
use Plack::Request;
use Apache2::FileManager::PSGI;
use Apache2::FileManager;
use String::Random qw(random_regex);
use rperloptions;
use rperltypes;
use rperltypesconv;  # string_to_integer()
use RPerl::Config;
#use RPerl::HelperFunctions_cpp;

# [[[ CONSTANTS ]]]
has posts_per_page => (
    isa     => Int,
    is      => 'ro',
    default => 10,
);
# NEED FIX: remove Moose, replace w/ RPerl constant below
#use constant POSTS_PER_PAGE => my integer $TYPED_POSTS_PER_PAGE = 10;

# [[ PACKAGE VARIABLES ]]

our hashref $KEY_CODES = {  # more listed here:  https://metacpan.org/pod/Term::ANSIMenu
    '__UR__'  => [ '', '' ],           # UPDATE REQUEST, accepted as input only, no output generated
    '__BL__'  => [ '__BL__', '__BL__' ],  # BLANK LINE, not accepted as input, only generated as output
    '__B__'  => [ "\x08", '__B__' ],   # BACKSPACE  "\b" does not work
    '__T__'  => [ "\x09", '__T__' ],   # TAB  "\t" does work
#    '__E__'  => [ "\x0A", '<br>' ],   # ENTER  "\n" does work
    '__E__'  => [ "\015", "\n" ],   # ENTER  "\015" for screen stuff
#    '__S__'  => [ "FOO", '__S__' ],   # SHIFT  UNTESTED
#    '__C__'  => [ "FOO", '__C__' ],   # CTRL  UNTESTED
    '__Cc__'  => [ "\x03", '__Cc__' ],   # CTRL-c  UNTESTED
#    '__A__'  => [ "FOO", '__A__' ],   # ALT  UNTESTED
    '__ES__' => [ "\e", '__ES__' ],  # ESCAPE  UNTESTED
#    '__SP__' => [ "\x20", '__SP__' ],  # SPACE  UNTESTED
#    '__PU__' => [ "\e[5~", '__PU__' ],  # PAGE UP  UNTESTED
#    '__PD__' => [ "\e[6~", '__PD__' ],  # PAGE DOWN  UNTESTED
#    '__EN__' => [ "\eOF", '__EN__' ],  # END   "\e[4~" & "\e[F" & "\eOF" does not work  NEED FIX
#    '__HO__' => [ "\eOH", '__HO__' ],  # HOME  "\e[1~" & "\e[H" & "\eOH" does not work  NEED FIX
#    '__AL__' => [ "\e[D", '__AL__' ],  # ARROW LEFT "\e[D" & "\e0D" does not work  NEED FIX 
#    '__AU__' => [ "\e[A", '__AU__' ],  # ARROW UP
#    '__AR__' => [ "\e[C", '__AR__' ],  # ARROW RIGHT
#    '__AD__' => [ "\e[B", '__AD__' ],  # ARROW DOWN
#    '__I__'  => [ "\e[2~", '__I__' ],   # INSERT
    '__D__'  => [ "\x7F", '__D__' ],   # DELETE  "\e[3~" does not work NEED FIX
};

# [[[ SUBROUTINES & OO METHODS ]]]



# START HERE: FIX ALL THIS CODE BELOW!!!
# START HERE: FIX ALL THIS CODE BELOW!!!
# START HERE: FIX ALL THIS CODE BELOW!!!

sub GetOptions {
    my %options = @ARG;
    my $retval = q{};

    my $cgi = CGI->new();

    if (not $cgi->param('__getopt__')) {
        # Not a form submission, so display form
        $retval .= $cgi->start_form(-method => "POST", -action => "");
        $retval .= $cgi->start_table();
        foreach my $key (sort keys %options) {
            my $val = $options{$key};
            if ($key !~ m/^([\w\d\|]+)([=:][isf])?([\+!\@\%])?$/) {
                next; # Not sure what this is
            }

            my $name = [split('|', $1, 1)]->[0];
            $retval .= $cgi->start_Tr();
            $retval .= $cgi->th($name . ($2 || ""));

            my $inner;
            if (($3 || "") eq '+') {
                die "Cannot mix + and params" if $2;
                $inner = $cgi->popup_menu(-name => $name, -values => [1..9]);
            } elsif (($3 || "") eq '!') {
                die "Cannot mix ! and params" if $2;
                $inner = $cgi->checkbox(-name => $name, -checked => 1);
            } elsif ($2) {
                $inner = $cgi->textfield(-name => $name);
                if (($3 || "") eq '%' or ($3 || "") eq '@' or ref($val) eq 'ARRAY' or ref($val) eq 'HASH') {
                    $inner = [$inner, $cgi->br(), $inner, $cgi->br(), $inner];
                }
            } else {
                $inner = $cgi->checkbox(-name => $name);
            }

            $retval .= $cgi->td($inner);
            $retval .= $cgi->end_Tr();
        }
        $retval .= $cgi->end_table();
        # This name is looked for on submit
        $retval .= $cgi->submit(-name => '__getopt__', -value => 'Go');
        $retval .= $cgi->end_form();
        return $retval;
    }

    # CGI form submission, so grab responses
    foreach my $key (sort keys %options) {
        my $val = $options{$key};
        if ($key !~ m/^([\w\d\|]+)([=:][isf])?([\+!\@\%])?$/) {
            next; # Unknown item
        }

        my $name = [split('|', $1, 1)]->[0];

        if (($3 || "") eq '+') {
            $$val = $cgi->param($name); # "Incremental" integer
        } elsif ($2) {
            my @values = $cgi->param($name);
            my $type = $2;
            if (($3 || "") eq '%' or ref($val) eq 'HASH') {
                my %values = map { split /=/, $_, 1 } @values;
                if ($type =~ m/i$/) {
                    foreach my $k (keys %values) {
                        $values{$k} = int($values{$k})
                    }
                } elsif ($type =~ m/f$/) {
                    foreach my $k (keys %values) {
                        $values{$k} = 0 + $values{$k}
                    }
                }
                if (ref($val) eq 'CODE') {
                    while(my($k, $v) = each %values) {
                       $val->($name, $k, $v);
                    }
                } else {
                    %$val = %values;
                }
            } else {
                if ($type =~ m/i$/) {
                    @values = map { int($_) } @values;
                } elsif ($type =~ m/f$/) {
                    @values = map { 0 + $_ } @values;
                }
                if (($3 || "") eq '@' or ref($val) eq 'ARRAY') {
                    if (ref($val) eq 'CODE') {
                        $val->($name, \@values)
                    } else {
                        @$val = @values;
                    }
                } else {
                    if (ref($val) eq 'CODE') {
                        $val->($name, $values[0]);
                    } else {
                        $$val = $values[0];
                    }
                }
            }
        } else {
            # Checkbox
            $$val = $cgi->param($name) ? 1 : 0;
        }
    }
}






=head1 METHODS

=cut

=head2 base

Set up path and stash some useful info.

=cut

sub base : Chained( '/base' ) : PathPart( 'code' ) : CaptureArgs( 0 ) {
    my ( $self, $c ) = @ARG;
#    print {*STDOUT} '<<< DEBUG >>>: in Code::base(), received $self = ', "\n", Dumper($self), "\n\n";
#    print {*STDOUT} '<<< DEBUG >>>: in Code::base(), received $c = ', "\n", Dumper($c), "\n\n";
#    print {*STDOUT} '<<< DEBUG >>>: in Code::base()', "\n";
    print {*STDOUT} '<<< DEBUG >>>: in Code::base(), have time = ', time, "\n";


    # Stash the upload_dir setting
    $c->stash->{ upload_dir } = $c->config->{ upload_dir };

    # Stash the name of the controller
    $c->stash->{ controller } = 'Code';
}

=head2 view_editor

Display the IDE code editor.

=cut

sub editor_file_manager_input_ajax : Chained( 'base' ) : PathPart( 'editor_file_manager_input_ajax' ) {
    my ( $self, $c ) = @ARG;
#    print {*STDOUT} '<<< DEBUG >>>: in Code::editor_file_manager_input_ajax(), received $self = ', "\n", Dumper($self), "\n\n";
#    print {*STDOUT} '<<< DEBUG >>>: in Code::editor_file_manager_input_ajax(), received $c = ', "\n", Dumper($c), "\n\n";

    my $request = $c->request();

    # set up stash
    $c->stash->{template} = 'code/view_editor_file_manager_input_ajax.tt';
    $c->stash->{wrapper_disable} = 1;
    # DEV NOTE: directly modify stash entries for editor_file_manager, instead of indirect editor_file_manager_input_ajax, removes redundant data copies
    $c->stash->{editor_file_manager} = {};
    $c->stash->{editor_file_manager}->{output} = q{};

    # require user to be logged in
    if ((not defined $c->user) or
        (not exists  $c->user->{_user}) or
        (not defined $c->user->{_user}) or
        (not exists  $c->user->{_user}->{_column_data}) or
        (not defined $c->user->{_user}->{_column_data}) or
        (not exists  $c->user->{_user}->{_column_data}->{username}) or
        (not defined $c->user->{_user}->{_column_data}->{username})) {
       return; 
    }

    # Apache2::FileManager: file locations
    my $shiny_username = $c->user->{_user}->{_column_data}->{username};
    my $document_root = $ShinyCMS::ROOT_DIR . 'root/user_files/' . $shiny_username . '/';
    # TMP DEBUG
#    $document_root .= 'github_repos/rperl-latest/';
#    $document_root .= 'github_repos/rperl-latest/lib/RPerl/Learning/';

    # accept parameters
    my $parameters = $request->parameters();
    print {*STDOUT} '<<< DEBUG >>>: in Code::editor_file_manager_input_ajax(), have $parameters = ', Dumper($parameters), "\n";

    # process input or output file parameter(s), return
    if ((exists $parameters->{FILEMANAGER_curr_file}) and (defined $parameters->{FILEMANAGER_curr_file}) and ($parameters->{FILEMANAGER_curr_file} ne q{})) {
        my $filename = $parameters->{FILEMANAGER_curr_file};
#        print {*STDOUT} '<<< DEBUG >>>: in Code::editor_file_manager_input_ajax(), have $filename = ', q{'}, $filename, q{'}, "\n";

        # SECURITY: do not allow double-dots in filename, server-side check
        if (($filename =~ m/[^a-zA-Z0-9-_.\/]/gxms) or ($filename =~ m/[.][.]+/gxms)) {
            $c->stash->{editor_file_manager}->{output} =
                'ERROR: Unsupported character detected in file name ' . q{'} . $filename . q{'} . 
                ', please use only letters, numbers, hyphens, underscores, forward slashes, and single dots.';
            return;
        }

        # accept output file parameter(s) (AKA save AKA write), return file write success
        if ((exists $parameters->{FILEMANAGER_cmd}) and (defined $parameters->{FILEMANAGER_cmd}) and ($parameters->{FILEMANAGER_cmd} ne q{})) {
            if ($parameters->{FILEMANAGER_cmd} eq 'save') {
                if (not ((exists $parameters->{editor_ace_textarea}) and (defined $parameters->{editor_ace_textarea}))) 
                    { croak("\n" . q{ERROR ECOFMCSPA00, FILE MANAGER COMMAND SAVE, PARAMETERS: Missing HTML parameter 'editor_ace_textarea', should contain source code to be saved, croaking}); }
                my string $output_source_code = $parameters->{editor_ace_textarea};
                print {*STDOUT} '<<< DEBUG >>>: in Code::syntax_check(), have $output_source_code = ', "\n", $output_source_code, "\n\n";
                if ($output_source_code eq q{}) 
                    { croak("\n" . q{ERROR ECOFMCSPA01, FILE MANAGER COMMAND SAVE, PARAMETERS: Empty HTML parameter 'input_source_code', should contain source code to be saved, croaking}); }

                # NEED ANSWER: is this correct here?!?
                # append newline to avoid "ERROR ECOPAPC13, RPERL PARSER, PERL CRITIC VIOLATION: RPerl source code input file '/tmp/rperl_tempfileFOO.pl' does not end with newline character or line of all-whitespace characters, dying
                # append return character to avoid "ERROR ECOPAPC02, RPERL PARSER, PERL CRITIC VIOLATION: Perl::Critic::Policy::CodeLayout::RequireConsistentNewlines"
                $output_source_code .= "\r\n";

                (open my filehandleref $SAVE_FILEHANDLE, '>', ($document_root . $filename)) or do {
                    $c->stash->{editor_file_manager}->{output} = $OS_ERROR;
                    return;
                };
                (print {$SAVE_FILEHANDLE} $output_source_code) or do {
                    $c->stash->{editor_file_manager}->{output} = $OS_ERROR;
                    return;
                };
                (close $SAVE_FILEHANDLE) or do {
                    $c->stash->{editor_file_manager}->{output} = $OS_ERROR;
                    return;
                };
                $c->stash->{editor_file_manager}->{output} = 'SUCCESS: Source code saved in file name ' . q{'} . $filename . q{'} . '.';
                return;
            }
            else {
                $c->stash->{editor_file_manager}->{output} = 'ERROR: Unrecognized File Manager command ' . q{'} . $parameters->{FILEMANAGER_cmd} . q{'};
                return;
            }
        }
        else {
            # accept input file parameter (AKA open AKA read), return contents of file to editor
            my $input_file_lines = q{};
            (open my filehandleref $INPUT_FILEHANDLE, '<', ($document_root . $filename)) or do {
                $c->stash->{editor_file_manager}->{output} = $OS_ERROR;
                return;
            };
            while ( my $input_file_line = <$INPUT_FILEHANDLE> ) {
                $input_file_lines .= $input_file_line;
            }
            (close $INPUT_FILEHANDLE) or do {
                $c->stash->{editor_file_manager}->{output} = $OS_ERROR;
                return;
            };
            $c->stash->{editor_file_manager}->{output} = $input_file_lines;
            return;
        }
    }
    
    # NOT input or output file parameters(s), create Apache2::FileManager object, generate, return

    # Apache2::FileManager: override $r with $request_wrapped_psgi, thereby wrapping $r
    my $request_wrapped_psgi;
    undef *Apache2::FileManager::r;
    *Apache2::FileManager::r = sub { return $request_wrapped_psgi };

    # Apache2::FileManager: create new $request_wrapped_psgi, generate HTML
    $request_wrapped_psgi = Apache2::FileManager::PSGI::new_from_psgi($request->env, $document_root);
    my $handler_retval = Apache2::FileManager->handler_noprint();

    # AJAX & Apache2::FileManager:
    # intercept calls to f.submit() for submitting the FileManager form data, which is used by all file & directory links plus most primary features;
    # replace with calls to editor_file_manager_input_ajax() for submitting the same FileManager form data via CGI::Ajax
    my $ajax_call_string_filemanager = q{editor_file_manager_input_ajax( ['FILEMANAGER_curr_file', 'FILEMANAGER_curr_dir', 'FILEMANAGER_cmd', 'FILEMANAGER_arg', 'FILEMANAGER_last_select_all'], [js_editor_file_manager_div_update] );};
    my $ajax_call_string_file_content = q{editor_file_manager_input_ajax( ['FILEMANAGER_curr_file', 'FILEMANAGER_curr_dir', 'FILEMANAGER_cmd', 'FILEMANAGER_arg', 'FILEMANAGER_last_select_all'], [js_editor_file_content_update] );};
#    $ajax_call_string = q{alert('about to call editor_file_manager_input_ajax()...');} . "\n" . $ajax_call_string;
    $handler_retval =~ s/f\.submit\(\);/$ajax_call_string_filemanager/gxms;

    # AJAX & Apache2::FileManager: intercept calls to window.document.FileManager which does not work inside W2UI layout, 
    # replace with window.document.forms.namedItem("FileManager")
    # hardcoded example, intercepted
    #window.document.FileManager
    # hardcoded example, replacement
    #window.document.forms.namedItem("FileManager")
    $handler_retval =~ s/window\.document\.FileManager/window\.document\.forms\.namedItem\('FileManager'\)/gxms;

    # AJAX & Apache2::FileManager: links to raw files; cut-and-paste action toolbar; discard footer; 
        # add FILEMANAGER_curr_file parameter; disable help; simplify header
    my $handler_retval_tmp = q{};
    my integer $action_toolbar_found = 0;
    my string $action_toolbar_cut = q{};
    my string_arrayref $handler_retval_lines = [(split /\n/, $handler_retval)];
    for (my integer $i = 0; $i < ((scalar @{$handler_retval_lines}) - 1); $i++)  {
        my $handler_retval_line = $handler_retval_lines->[$i];
        my $handler_retval_line_next = $handler_retval_lines->[$i + 1];

        # AJAX & Apache2::FileManager: intercept links to raw files, replace with AJAX code
        # hardcoded example, intercepted
        #<A HREF="/PATH/TO/FOOBAR?nossi=1"
        #    TARGET=_blank><FONT COLOR=BLACK>FOOBAR</FONT>
        # hardcoded example, replacement
        #<A HREF=# onclick="
        #        var f=window.document.forms.namedItem('FileManager');
        #        f.FILEMANAGER_curr_file.value='FOO';
        #        editor_file_manager_input_ajax( ['FILEMANAGER_curr_file', 'FILEMANAGER_curr_dir', 'FILEMANAGER_cmd', 'FILEMANAGER_arg', 'FILEMANAGER_last_select_all'], [js_editor_file_content_update] );
        #        f.FILEMANAGER_curr_file.value='';
        #        return false;">
        #        <FONT COLOR=BLACK>FOOBAR</FONT>
        if (((substr $handler_retval_line, 0, 23 ) eq '              <A HREF="') and 
            ((substr $handler_retval_line, -9, 9 ) eq '?nossi=1"')) {
                my $path = $handler_retval_line;
                substr $path, 0, 23, q{};  # trim leading HTML
                substr $path, -9, 9, q{};  # trim trailing HTML
                my $filename = $handler_retval_line_next;
                substr $filename, 0, 49, q{};  # trim leading HTML
                substr $filename, -7, 7, q{};  # trim trailing HTML
                $handler_retval_tmp .=<<"EOL";
        <A HREF=# onclick="
            var f=window.document.forms.namedItem('FileManager');
            f.FILEMANAGER_curr_file.value='$path';
            $ajax_call_string_file_content
            f.FILEMANAGER_curr_file.value='';
            return false;">
            <FONT COLOR=BLACK>$filename</FONT>
EOL
            $i++; # discard following line which has been replaced in heredoc above:    TARGET=_blank><FONT COLOR=BLACK>FOOBAR</FONT>
            next;
        }

        if ($handler_retval_line_next eq '    function display_help () {') {
            $i += 39;  # disable help link code
            next;
        }
        if ($handler_retval_line_next eq '            <FONT SIZE=+2 COLOR=#3a3a3a>') {
            $i += 3;  # discard huge 'cloudforfree.org - file manager' in header
            $i += 6;  # disable help link
            $handler_retval_tmp .= '          <td><b><u>File Manager</u></b></td>' . "\n";
            next;
        }
        if ($handler_retval_line_next eq '    <!-- Actions Tool bar -->') {
            # second line of action toolbar
            #$action_toolbar_cut .= $handler_retval_line . "\n";  # discard unneeded '<TR><TD>'
            $action_toolbar_cut .= $handler_retval_line_next . "\n";
            $action_toolbar_found = 1;
            $i++;
            $i += 3;  # discard unneeded '<TABLE CELLPADDING=0 CELLSPACING=0 BORDER=0><TR ALIGN=CENTER>'
            next;
        }
        if ($action_toolbar_found) {
            if ($handler_retval_line eq '        ><FONT COLOR=WHITE><B>upload</B></FONT></A></TD></TR></TABLE></TD></TR>') {
                # last line of action toolbar
                #substr $handler_retval_line, -10, 10, q{};  # discard unneeded '</TD></TR>'
                substr $handler_retval_line, -18, 18, q{};  # discard unneeded '</TABLE></TD></TR>'
                $action_toolbar_found = 0;
            }
            # last or inner line of action toolbar
            $action_toolbar_cut .= $handler_retval_line . "\n";
            next;
        }
        if ($handler_retval_line eq '      <!-- Footer -->') {
            # replace footer with action toolbar & closing HTML, exit loop
            $action_toolbar_cut =~ s/&nbsp;/ /gxms;
            $action_toolbar_cut =~ s/<TD>//gxms;
            $action_toolbar_cut =~ s/<\/TD>//gxms;
            $action_toolbar_cut =~ s/<TD\ ALIGN\=CENTER>//gxms;
            $action_toolbar_cut =~ s/<TR>//gxms;
            $action_toolbar_cut =~ s/<\/TR>//gxms;
            $handler_retval_tmp .= $action_toolbar_cut . "\n";
            $handler_retval_tmp .= '    </FORM>' . "\n" . '    </HTML>' . "\n";
            last;
        }

        # hardcoded example, find:    <INPUT TYPE=HIDDEN NAME=FILEMANAGER_curr_dir
        # hardcoded example, prepend: <INPUT TYPE=HIDDEN NAME=FILEMANAGER_curr_file VALUE=''>
        if ($handler_retval_line eq '    <INPUT TYPE=HIDDEN NAME=FILEMANAGER_curr_dir') {
            $handler_retval_tmp .= q{    <INPUT TYPE=HIDDEN NAME=FILEMANAGER_curr_file VALUE=''>} . "\n";
        }
        $handler_retval_tmp .= $handler_retval_line . "\n";
    }
    $handler_retval = $handler_retval_tmp;

    # save space for slimmer sidebar
    $handler_retval =~ s/last\ modified/date/gxms;
    $handler_retval =~ s/new\ directory/new&nbsp;directory/gxms;

    # AJAX: create objects
    my CGI $cgi = CGI->new();
    my CGI::Ajax $cgi_ajax = new CGI::Ajax( editor_file_manager_input_ajax => 'editor_file_manager_input_ajax', skip_header => 1 );
    $cgi_ajax->skip_header(1);

    # AJAX: build & stash
    # initial call from view_editor(), no parameters, do include AJAX javascript from build_html()
    if (not exists $parameters->{FILEMANAGER_curr_dir}) {
#        $handler_retval = $cgi_ajax->build_html($cgi, $handler_retval);
        $c->stash->{editor_file_manager}->{output_js} = $cgi_ajax->show_javascript();
    }
    # subsequent calls from user clicking on links, yes parameters, do not include AJAX javascript from build_html()
    $c->stash->{editor_file_manager}->{output} = $handler_retval;

    # DEBUG OUTPUT
#    open(my $fh, '>', '/tmp/handler_retval.out');
#    print {$fh} $handler_retval;
#    close $fh;
}


sub view_editor : Chained( 'base' ) : PathPart( 'editor' ) {
    my ( $self, $c ) = @ARG;
#    print {*STDOUT} '<<< DEBUG >>>: in Code::view_editor(), received $self = ', "\n", Dumper($self), "\n\n";
#    print {*STDOUT} '<<< DEBUG >>>: in Code::view_editor(), received $c = ', "\n", Dumper($c), "\n\n";

    my $request = $c->request();
    # NEED ANSWER: are we going to accept input parameters on this page?
#    my $parameters = $request->parameters();
#    if ((exists $parameters->{editor_ace_textarea}) and (defined $parameters->{editor_ace_textarea})) {
#        my $editor_ace_textarea = $parameters->{editor_ace_textarea};
#        print {*STDOUT} '<<< DEBUG >>>: in Code::view_editor(), have parameter $editor_ace_textarea = ', "\n", Dumper($editor_ace_textarea), "\n\n";
#    }

    # create default file manager
    editor_file_manager_input_ajax($self, $c);

    # set up stash, must be after call to editor_file_manager_input_ajax()
    $c->stash->{ template } = 'code/view_editor.tt';
    $c->stash->{wrapper_disable} = 0;
    $c->stash->{ editor } = { title => 'IDE Code Editor' };

    # require user to be logged in
    if ((not defined $c->user) or
        (not exists  $c->user->{_user}) or
        (not defined $c->user->{_user}) or
        (not exists  $c->user->{_user}->{_column_data}) or
        (not defined $c->user->{_user}->{_column_data}) or
        (not exists  $c->user->{_user}->{_column_data}->{username}) or
        (not defined $c->user->{_user}->{_column_data}->{username})) {
       return; 
    }

    # ACE Editor: default source code file input
    my $learning_rperl_ch1_ex1 = <<'EOF';
#!/usr/bin/perl

# Learning RPerl, Chapter 1, Exercise 1
# Print "Hello, world!"; the classic first program for new programmers

# [[[ HEADER ]]]
use RPerl;
use strict;
use warnings;
our $VERSION = 0.001_000;

# [[[ CRITICS ]]]
## no critic qw(ProhibitUselessNoCritic ProhibitMagicNumbers RequireCheckedSyscalls)  # USER DEFAULT 1: allow numeric values & print operator

# [[[ OPERATIONS ]]]
print 'Hello, world!', "\n";
EOF
    $c->stash->{ file_input } = { default => $learning_rperl_ch1_ex1 };
}

=head2 view_repos

Display the GitHub repos manager.

=cut

sub view_repos : Chained( 'base' ) : PathPart( 'repos' ) {
    my ( $self, $c ) = @ARG;
#    print {*STDOUT} '<<< DEBUG >>>: in Code::view_repos(), received $self = ', "\n", Dumper($self), "\n\n";
#    print {*STDOUT} '<<< DEBUG >>>: in Code::view_repos(), received $c = ', "\n", Dumper($c), "\n\n";

    $c->stash->{ template } = 'code/view_repos.tt';
    $c->stash->{ repos } = { };
    $c->stash->{ repos }->{ title } = 'GiHub Repos Manager';
    $c->stash->{ repos }->{ NEED_ADD_OTHER_DATA } = 2_112;

    # require user to be logged in
    if ((not defined $c->user) or
        (not exists  $c->user->{_user}) or
        (not defined $c->user->{_user}) or
        (not exists  $c->user->{_user}->{_column_data}) or
        (not defined $c->user->{_user}->{_column_data}) or
        (not exists  $c->user->{_user}->{_column_data}->{username}) or
        (not defined $c->user->{_user}->{_column_data}->{username})) {
       return; 
    }
}

=head2 view_queue

Display the job queue.

=cut

sub view_queue : Chained( 'base' ) : PathPart( 'queue' ) {
    my ( $self, $c ) = @ARG;
#    print {*STDOUT} '<<< DEBUG >>>: in Code::view_queue(), received $self = ', "\n", Dumper($self), "\n\n";
#    print {*STDOUT} '<<< DEBUG >>>: in Code::view_queue(), received $c = ', "\n", Dumper($c), "\n\n";

    my $request = $c->request();
#    print {*STDOUT} '<<< DEBUG >>>: in Code::view_queue(), have $request->param() = ', "\n", Dumper($request->param()), "\n\n";
#    print {*STDOUT} '<<< DEBUG >>>: in Code::view_queue(), have $request->parameters() = ', "\n", Dumper($request->parameters()), "\n\n";

    $c->stash->{template} = 'code/view_queue.tt';
    $c->stash->{queue} = {};
    $c->stash->{queue}->{title} = 'Job Queue';

    # require user to be logged in
    if ((not defined $c->user) or
        (not exists  $c->user->{_user}) or
        (not defined $c->user->{_user}) or
        (not exists  $c->user->{_user}->{_column_data}) or
        (not defined $c->user->{_user}->{_column_data}) or
        (not exists  $c->user->{_user}->{_column_data}->{username}) or
        (not defined $c->user->{_user}->{_column_data}->{username})) {
       return; 
    }

    # username used in generated cloud command prompt
    my string $username = $c->user->{_user}->{_column_data}->{username};
    $c->stash->{queue}->{username} = $username;

    # list of all RPerl options, arguments, modes; generate HTML
#    my $rperl_options_html = q{};
#    $rperl_options_html .= 'RPERL COMMAND-LINE OPTIONS' . '<br>';
#    $rperl_options_html .= '<br>';
#    $rperl_options_html .= GetOptions ( %{$::rperl_options} ) or die("Error in command line arguments\n");
#    $c->stash->{queue}->{rperl_options_html} = $rperl_options_html;
}

=head2 syntax_check

Check the RPerl syntax of input source code.

=cut

sub syntax_check : Chained( 'base' ) : PathPart( 'syntax_check' ) {
    my ( $self, $c ) = @ARG;
#    print {*STDOUT} '<<< DEBUG >>>: in Code::syntax_check(), received $self = ', "\n", Dumper($self), "\n\n";
#    print {*STDOUT} '<<< DEBUG >>>: in Code::syntax_check(), received $c = ', "\n", Dumper($c), "\n\n";

    my $request = $c->request();
#    print {*STDOUT} '<<< DEBUG >>>: in Code::syntax_check(), have $request->param() = ', "\n", Dumper($request->param()), "\n\n";
#    print {*STDOUT} '<<< DEBUG >>>: in Code::syntax_check(), have $request->parameters() = ', "\n", Dumper($request->parameters()), "\n\n";

    # set up stash
    $c->stash->{template} = 'code/view_syntax_check.tt';
    $c->stash->{syntax_check} = {};
    $c->stash->{syntax_check}->{title} = 'Syntax Check';
    $c->stash->{syntax_check}->{stdout_stderr} = q{};

    # require user to be logged in
    if ((not defined $c->user) or
        (not exists  $c->user->{_user}) or
        (not defined $c->user->{_user}) or
        (not exists  $c->user->{_user}->{_column_data}) or
        (not defined $c->user->{_user}->{_column_data}) or
        (not exists  $c->user->{_user}->{_column_data}->{username}) or
        (not defined $c->user->{_user}->{_column_data}->{username})) {
       return; 
    }

    # accept HTML parameters
    my $parameters = $request->parameters();
    if (not ((exists $parameters->{editor_ace_textarea}) and (defined $parameters->{editor_ace_textarea}))) 
        { croak("\n" . q{ERROR ECOSCPA00, SYNTAX CHECK, PARAMETERS: Missing HTML parameter 'editor_ace_textarea', should contain source code to be syntax checked, croaking}); }
    my string $output_source_code = $parameters->{editor_ace_textarea};
    print {*STDOUT} '<<< DEBUG >>>: in Code::syntax_check(), have $output_source_code = ', "\n", $output_source_code, "\n\n";
    if ($output_source_code eq q{}) 
        { croak("\n" . q{ERROR ECOSCPA01, SYNTAX CHECK, PARAMETERS: Empty HTML parameter 'input_source_code', should contain source code to be syntax checked, croaking}); }
    # append newline to avoid "ERROR ECOPAPC13, RPERL PARSER, PERL CRITIC VIOLATION: RPerl source code input file '/tmp/rperl_tempfileFOO.pl' does not end with newline character or line of all-whitespace characters, dying
    # append return character to avoid "ERROR ECOPAPC02, RPERL PARSER, PERL CRITIC VIOLATION: Perl::Critic::Policy::CodeLayout::RequireConsistentNewlines"
    $output_source_code .= "\r\n";

    # create temporary file
    my string $file_suffix;
    if ((substr $output_source_code, 0, 15) eq '#!/usr/bin/perl') { $file_suffix = 'pl'; }
    else                                                         { $file_suffix = 'pm'; }
    my filehandleref $FILE_HANDLE_REFERENCE_TMP;
    my string $file_name_reference_tmp;
    ( $FILE_HANDLE_REFERENCE_TMP, $file_name_reference_tmp ) = tempfile( 'rperl_tempfileXXXX', SUFFIX => q{.} . $file_suffix, UNLINK => 1, TMPDIR => 1 );
    print {*STDOUT} '<<< DEBUG >>>: in Code::syntax_check(), have $file_name_reference_tmp = ', q{'}, $file_name_reference_tmp, q{'}, "\n" ;
 
    # save source code into temporary file
    print {$FILE_HANDLE_REFERENCE_TMP} $output_source_code
        or croak("\nERROR ECOSCFI00, SYNTAX CHECK, FILE SYSTEM: Attempting to save new file '$file_name_reference_tmp', cannot write to file,\ncroaking: $OS_ERROR");
    close $FILE_HANDLE_REFERENCE_TMP 
        or croak("\nERROR ECOSCFI01, SYNTAX CHECK, FILE SYSTEM: Attempting to save new file '$file_name_reference_tmp', cannot close file,\ncroaking: $OS_ERROR");

    # create syntax check command string
    my string $syntax_check_command = 'rperl --Verbose --Debug --Warnings --mode ops=PERL --mode types=PERL --mode compile=GENERATE --mode parallel=OFF --mode execute=OFF ' . $file_name_reference_tmp;
#    my string $syntax_check_command = 'rperl -V -D -W -t -nop -noe ' . $file_name_reference_tmp;  # short-hand

    print {*STDOUT} '<<< DEBUG >>>: in Code::syntax_check(), have $syntax_check_command = ', $syntax_check_command, "\n";

    my string $stdout_stderr = q{};

    print {*STDOUT} '<<< DEBUG >>>: in Code::syntax_check(), START running $syntax_check_command = ', $syntax_check_command, "\n";

    # run syntax check command
    run3( $syntax_check_command, \undef, \$stdout_stderr, \$stdout_stderr );

    print {*STDOUT} '<<< DEBUG >>>: in Code::syntax_check(), FINISH running $syntax_check_command = ', $syntax_check_command, "\n";

    my $syntax_check_exit_status = $CHILD_ERROR >> 8;

    print {*STDOUT} '<<< DEBUG >>>: in Code::syntax_check(), have $CHILD_ERROR = ', $CHILD_ERROR, "\n" ;
    print {*STDOUT} '<<< DEBUG >>>: in Code::syntax_check(), have $syntax_check_exit_status = ', $syntax_check_exit_status, "\n" ;

    my boolean $stdout_stderr_content = ( ( defined $stdout_stderr ) and ( $stdout_stderr =~ m/[^\s]+/g ) );

    # stash syntax check command output
    if ( $stdout_stderr_content ) {
        print {*STDOUT} "\n", '<<< DEBUG >>>: in Code::syntax_check(), have [[[ SYNTAX CHECK COMMAND STDOUT & STDERR ]]]', "\n\n", $stdout_stderr, "\n" ;
        $c->stash->{syntax_check}->{stdout_stderr} = $stdout_stderr;
    }

    if ($syntax_check_exit_status) {               # UNIX process exit status (AKA return code) not 0, error
    # syntax errors cause error exit status, but we don't want to actually croak
#        if ( not $stdout_stderr_content ) {
#            print {*STDOUT}  "\n", '[[[ SYNTAX CHECK COMMAND STDOUT & STDERR ARE BOTH EMPTY ]]]', "\n\n" ;
#        }
#        croak 'ERROR ECOSCES, SYNTAX CHECK, COMMAND: RPerl compiler returned error exit status,', "\n"
#           , 'please run again with `rperl -D` command or RPERL_DEBUG=1 environmental variable for error messages if none appear above,', "\n"
#           , 'croaking';
        $c->stash->{syntax_check}->{stdout_stderr} .= "\n\n" . '[[[ SYNTAX ERRORS WERE FOUND ]]]';
    }
    else {
        $c->stash->{syntax_check}->{stdout_stderr} .= "\n\n" . '[[[ NO SYNTAX ERRORS WERE FOUND ]]]';
    }
}


=head2 run_command_input_ajax

Interface with running RPerl command.

=cut

sub run_command_input_ajax : Chained( 'base' ) : PathPart( 'run_command_input_ajax' ) {
    my ( $self, $c ) = @ARG;
#    print {*STDOUT} '<<< DEBUG >>>: in Code::run_command_input_ajax(), received $self = ', "\n", Dumper($self), "\n\n";
#    print {*STDOUT} '<<< DEBUG >>>: in Code::run_command_input_ajax(), received $c = ', "\n", Dumper($c), "\n\n";

    # set up stash
    $c->stash->{template} = 'code/view_run_command_input_ajax.tt';
    $c->stash->{wrapper_disable} = 1;
    $c->stash->{run_command_input_ajax} = {};
    $c->stash->{run_command_input_ajax}->{output} = q{};
    my string $stdout_stderr = q{};

    # require user to be logged in
    if ((not defined $c->user) or
        (not exists  $c->user->{_user}) or
        (not defined $c->user->{_user}) or
        (not exists  $c->user->{_user}->{_column_data}) or
        (not defined $c->user->{_user}->{_column_data}) or
        (not exists  $c->user->{_user}->{_column_data}->{username}) or
        (not defined $c->user->{_user}->{_column_data}->{username})) {
       return; 
    }

    # require pid & input parameters
    my $request = $c->request();
    my $parameters = $request->parameters();
    if (not ((exists $parameters->{run_command_pid}) and (defined $parameters->{run_command_pid}))) {
        croak("\n" . q{ERROR ECORCIAPA00, RUN COMMAND INPUT AJAX, PARAMETERS: Missing HTML parameter 'run_command_pid', should contain PID of running command, croaking});
    }
    if ((not exists $parameters->{run_command_input_param}) and (not defined $parameters->{run_command_input_param}) and
        (not exists $parameters->{run_command_input_param_update_request}) and (not defined $parameters->{run_command_input_param_update_request})) {
        croak("\n" . q{ERROR ECORCIAPA01, RUN COMMAND INPUT AJAX, PARAMETERS: Missing HTML parameter 'run_command_input_param' or 'run_command_input_param_update_request', should contain input for running command or update request, croaking});
    }

    # accept pid & input parameters
    my $pid = $parameters->{run_command_pid};
    my $input;
    # accept real user input if present, otherwise accept automated update request input
    if ((exists $parameters->{run_command_input_param}) and (defined $parameters->{run_command_input_param})) {
        $input = $parameters->{run_command_input_param};
    }
    else {
        $input = $parameters->{run_command_input_param_update_request};
    }
    print {*STDOUT} '<<< DEBUG >>>: in Code::run_command_input_ajax(), have $pid = ', $pid, "\n";
    print {*STDOUT} '<<< DEBUG >>>: in Code::run_command_input_ajax(), have $input = ', q{'}, $input, q{'}, "\n";

    # MULTI-THREADED
    # retrieve entry from job_running database table
    my $job_running_entry = $c->model( 'DB::JobRunning' )->find({ screen_pid => $pid });
    print {*STDERR} '<<< DEBUG >>>: in Code::run_command_input_ajax() MULTI-THREADED, have $job_running_entry->{_column_data} = ', Dumper($job_running_entry->{_column_data}), "\n";
    my string $screen_session = $job_running_entry->screen_session;
    print {*STDERR} '<<< DEBUG >>>: in Code::run_command_input_ajax() MULTI-THREADED, have $screen_session = ', $screen_session, "\n";
    my string $screen_logfile = $job_running_entry->screen_logfile;
    print {*STDERR} '<<< DEBUG >>>: in Code::run_command_input_ajax() MULTI-THREADED, have $screen_logfile = ', $screen_logfile, "\n";
    my string $output_line = $job_running_entry->output_line;
    print {*STDERR} '<<< DEBUG >>>: in Code::run_command_input_ajax() MULTI-THREADED, have $output_line = ', $output_line, "\n";
    my string $output_character = $job_running_entry->output_character;
    print {*STDERR} '<<< DEBUG >>>: in Code::run_command_input_ajax() MULTI-THREADED, have $output_character = ', $output_character, "\n";

    # strip trailing newline from input
    chomp $input;

    if ($input ne '__UR__') {  # BEGIN REAL INPUT, NOT UPDATE REQUEST
        # START HERE: handle other special keys, then add JS cursor handler    http://stackoverflow.com/questions/512528/set-cursor-position-in-html-textbox
        # START HERE: handle other special keys, then add JS cursor handler    http://stackoverflow.com/questions/512528/set-cursor-position-in-html-textbox
        # START HERE: handle other special keys, then add JS cursor handler    http://stackoverflow.com/questions/512528/set-cursor-position-in-html-textbox

        # decode ENTER key if found; do NOT append input to output which has been read
        if (exists $KEY_CODES->{$input}) {
            my string $input_copy = $input;
            $input = $KEY_CODES->{$input_copy}->[0];
#            $stdout_stderr .= $KEY_CODES->{$input_copy}->[1];    # disable direct input append for keycode characters, wait to read from logfile
        }
#        else { $stdout_stderr .= $input; }  # disable direct input append for non-keycode characters, wait to read from logfile

    # MULTI-THREADED

#=DISABLE_PTY
#    # provide input to and/or receive output from command via PTY
#    my string $screen_reattach_command = 'screen -r ' . $screen_session;
#    print {*STDERR} '<<< DEBUG >>>: in Code::run_command_input_ajax() MULTI-THREADED, have $screen_reattach_command = ', $screen_reattach_command, "\n";
#    my $screen_pty = IO::Pty::Easy->new;
#    # reattach to screen session
#    $screen_pty->spawn($screen_reattach_command);
#    sleep 1;  # give time for output to accrue
#
#    my string $stdout_stderr_tmp = undef;
#
##    my $written_characters;
##    if ((defined $input) and ($input ne '')) { $written_characters = $screen_pty->write($input, 0); }  # replaced by $screen_stuff_command above
##    if (not ((defined $written_characters) and ($written_characters == 0))) {
#        $stdout_stderr_tmp = $screen_pty->read(0);
##    }
##    if ((defined $stdout_stderr_tmp) and ($stdout_stderr_tmp eq '')) { last; }
#
#    if (defined $stdout_stderr_tmp) { 
#        # NEED ANSWER: what in the world is this string of crazy control characters?
#        my string $pty_control_string = ')0[?1049h[4l[?1h=[0m(B[1;57r[H[J[H[J[33B';
#        $stdout_stderr_tmp =~ s/\Q$pty_control_string\E//gxms;
#        $stdout_stderr .= $stdout_stderr_tmp;
#    }
#
#    $screen_pty->close;
#=cut

        # provide input to command via screen stuff
        my string $screen_stuff_command = 'screen -r ' . $screen_session . ' -p0 -X stuff "' . $input . '"';
        print {*STDERR} '<<< DEBUG >>>: in Code::run_command_input_ajax(), about to run $screen_stuff_command = ', $screen_stuff_command, "\n";
        my string $screen_stuff_command_retval = `$screen_stuff_command 2>&1;`;
        print {*STDERR} '<<< DEBUG >>>: in Code::run_command_input_ajax(), have $CHILD_ERROR = ', $CHILD_ERROR, ', $screen_stuff_command_retval = ', $screen_stuff_command_retval, "\n";
        if ($CHILD_ERROR) { $c->stash->{run_command}->{stdout_stderr} = 'ERROR: Failed to provide input to `screen` session; ' . $screen_stuff_command_retval; return; }
        $job_running_entry->update({ status => 'command_running' });
    }  # END REAL INPUT, NOT UPDATE REQUEST

    # grab output from command via screen logfile
    my @screen_logfile_tied;
    my boolean $screen_logfile_tie_success = tie @screen_logfile_tied, 'Tie::File', $screen_logfile, mode => 'O_RDONLY', autochomp => 0;
    if (not $screen_logfile_tie_success) {
        $c->stash->{run_command}->{stdout_stderr} = 'ERROR: Failed to read output from `screen` session, can not tie to logfile';
        return;
    }
    my integer $screen_logfile_num_lines = scalar @screen_logfile_tied;
    print {*STDERR} '<<< DEBUG >>>: in Code::run_command_input_ajax(), have $screen_logfile_num_lines = ', $screen_logfile_num_lines, "\n";
    if ($output_line > $screen_logfile_num_lines) {
        $c->stash->{run_command}->{stdout_stderr} = 'ERROR: Failed to read output from `screen` session, attempt to read beyond end of logfile';
        return;
    }
    my string $screen_logfile_line = $screen_logfile_tied[$output_line - 1];  # adjust by 1 for line count vs array index count
    my integer $screen_logfile_line_num_chars = length $screen_logfile_line;
    if ($output_character > $screen_logfile_line_num_chars) {
        $c->stash->{run_command}->{stdout_stderr} = 'ERROR: Failed to read output from `screen` session, attempt to read beyond end of logfile line';
        return;
    }
    $stdout_stderr .= substr $screen_logfile_line, ($output_character - 1);  # adjust by 1 for character count vs substr index count
    $output_character = $screen_logfile_line_num_chars;
    if ($screen_logfile_num_lines > $output_line) {
        for my integer $i (($output_line + 1) .. $screen_logfile_num_lines) {
            $output_line = $i;
            $screen_logfile_line = $screen_logfile_tied[$output_line - 1];  # adjust by 1 for line count vs array index count
            $stdout_stderr .= $screen_logfile_line;
        }
        $output_character = length $screen_logfile_line;
    }

# START HERE: fix "untie attempted while 1 inner references still exist" below, likely caused to accepting input after job has completed
# START HERE: fix "untie attempted while 1 inner references still exist" below, likely caused to accepting input after job has completed
# START HERE: fix "untie attempted while 1 inner references still exist" below, likely caused to accepting input after job has completed

    untie @screen_logfile_tied;
    $job_running_entry->update({ output_line => $output_line, output_character => $output_character });

    # strip ^M newline control characters read from logfile
    $stdout_stderr =~ s/\015//gxms;

    print {*STDOUT} '<<< DEBUG >>>: in Code::run_command_input_ajax(), about to return $stdout_stderr = ', $stdout_stderr, "\n";

    # KEYCODE, encode $stdout_stderr using keycodes
    my string_arrayref $stdout_stderr_keycoded_lines = [];
    foreach my $stdout_stderr_line (split /\n/, $stdout_stderr) {
        if ($stdout_stderr_line eq q{}) {
            push @{$stdout_stderr_keycoded_lines}, '__BL__';
        }
        else {
            push @{$stdout_stderr_keycoded_lines}, $stdout_stderr_line;
        }
    }
    my string $stdout_stderr_keycoded = join "\n", @{$stdout_stderr_keycoded_lines};

#    $c->stash->{run_command_input_ajax}->{output} = $stdout_stderr;
    $c->stash->{run_command_input_ajax}->{output} = $stdout_stderr_keycoded;

#=DISABLE_DETACH_UNNEEDED
#    # MULTI-THREADED
#    # detach from screen session
#    my string $screen_detach_command = 'screen -S ' . $screen_session . ' -X detach';
#    print {*STDERR} '<<< DEBUG >>>: in Code::run_command_input_ajax() MULTI-THREADED, about to run $screen_detach_command = ', $screen_detach_command, "\n";
#    my string $screen_detach_command_retval = `$screen_detach_command 2>&1;`;
#    print {*STDERR} '<<< DEBUG >>>: in Code::run_command_input_ajax() MULTI-THREADED, have $CHILD_ERROR = ', $CHILD_ERROR, ', $screen_detach_command_retval = ', $screen_detach_command_retval, "\n";
#    if ($CHILD_ERROR) { $c->stash->{run_command_input_ajax}->{output} .= "\n" . 'ERROR: Failed to detach running `screen` session; ' . $screen_detach_command_retval; return; }
#=cut
}


sub run_command : Chained( 'base' ) : PathPart( 'run_command' ) {
    my ( $self, $c ) = @ARG;
#    print {*STDOUT} '<<< DEBUG >>>: in Code::run_command(), received $self = ', "\n", Dumper($self), "\n\n";
#    print {*STDOUT} '<<< DEBUG >>>: in Code::run_command(), received $c = ', "\n", Dumper($c), "\n\n";

    my $request = $c->request();
#    print {*STDOUT} '<<< DEBUG >>>: in Code::run_command(), have $request->param() = ', "\n", Dumper($request->param()), "\n\n";
#    print {*STDOUT} '<<< DEBUG >>>: in Code::run_command(), have $request->parameters() = ', "\n", Dumper($request->parameters()), "\n\n";

    # set up stash
    $c->stash->{template} = 'code/view_run_command.tt';
    $c->stash->{run_command} = {};
    $c->stash->{run_command}->{title} = 'Run Command';
    $c->stash->{run_command}->{command} = q{};
    $c->stash->{run_command}->{pid} = q{};
    $c->stash->{run_command}->{stdout_stderr} = q{};
    $c->stash->{run_command}->{output_ajax} = q{};

#=DISABLE_COMMAND
#    # require command parameter
#    my $parameters = $request->parameters();
#    if (not ((exists $parameters->{command}) and (defined $parameters->{command}))) {
#        croak("\n" . q{ERROR ECORCPA00, RUN COMMAND, PARAMETERS: Missing HTML parameter 'command', should contain command to be run, croaking});
#    }
#
#    # accept command parameter
#    my string $command = $parameters->{command};
#    print {*STDOUT} '<<< DEBUG >>>: in Code::run_command(), have $command = ', $command, "\n";
#
#    # SECURITY: disallow multiple commands, only allow 1 RPerl command!
#    if ($command =~ m/[;|><\\]/) {
#        print {*STDOUT}  '<<< DEBUG >>>: SECURITY: in Code::run_command(), intercepted command with forbidden control character', "\n";
#        $c->stash->{run_command}->{stdout_stderr} = 'ERROR: Command with forbidden control character ; or | or < or > or \';
#        return;
#    }
#
#    # SECURITY: all commands must be RPerl commands!
#    $command = 'rperl ' . $command;
#=cut

    # require filename parameter
    my $parameters = $request->parameters();
    if (not ((exists $parameters->{filename}) and (defined $parameters->{filename}))) {
        croak("\n" . q{ERROR ECORCPA00, RUN COMMAND, PARAMETERS: Missing HTML parameter 'filename', should contain filename to be run, croaking});
    }
    # accept filename parameter
    my string $filename = $parameters->{filename};
    print {*STDOUT} '<<< DEBUG >>>: in Code::run_filename(), have $filename = ', $filename, "\n";

    # SECURITY: disallow multiple filenames, only allow 1 RPerl filename!
    if ($filename =~ m/[;|><\\ ]/) {
        print {*STDOUT}  '<<< DEBUG >>>: SECURITY: in Code::run_command(), intercepted filename with forbidden control character', "\n";
        $c->stash->{run_command}->{stdout_stderr} = q{ERROR: Command with forbidden control character semi-colon ';' or vertical-pipe '|' or less-than '<' or greater-than '>' or backslash '\' or space ' '};
        return;
    }

    # username used in generated cloud command prompt
    my string $username = $c->user->{_user}->{_column_data}->{username};
    $c->stash->{run_command}->{username} = $username;

    # SECURITY: all commands must be RPerl commands!
    my string $command = 'rperl -t -nop ' . $ShinyCMS::ROOT_DIR . 'root/user_files/' . $username . '/' . $filename;

    # SECURITY: store SANITIZED command back in stash to be displayed
    $c->stash->{run_command}->{command_sanitized} = 'rperl -t -nop ' . $filename;

    # SECURITY: run all commands as www-data user; we automatically inherit PERL env vars, must explicitly inherit PATH env var
    # DEV NOTE: when using open3(), must use `unbuffer -p` to avoid 4K libc buffer min limit, which requires erroneous newline input before unblocking output
#    $command = q{su www-data -c "PATH=$PATH; set | grep TERM; unbuffer -p } . $command . q{"};
#    $command = q{su www-data -c "PATH=$PATH; unbuffer -p } . $command . q{"};


    # DEV NOTE: must sleep to get output in correct order, then sleep again to write logfile
    $command = q{su www-data -c "PATH=$PATH; } . $command . q{"; sleep 1; echo; echo __JOB_COMPLETED__; sleep 1; exit};  # ORIGINAL
#    $command = q{su www-data -c "PATH=$PATH; RPERL_DEBUG=1; RPERL_VERBOSE=1; which rperl; rperl -v; } . $command . q{"; sleep 1; echo; echo __JOB_COMPLETED__; sleep 1; exit};
#    $command = q{su www-data -c "PATH=$PATH; RPERL_DEBUG=1; RPERL_VERBOSE=1; which rperl; "; sleep 1; echo; echo __JOB_COMPLETED__; sleep 1; exit};


#    $command = q{su www-data -c "PATH=$PATH; unbuffer -p } . $command . q{"; echo; read -p JOB_COMPLETED__PRESS_ENTER_TO_CLOSE; exit};

# START HERE: add ssh to other compute_nodes, must use `ssh -t` to avoid screen 'Must be connected to a terminal.' error
# START HERE: add ssh to other compute_nodes, must use `ssh -t` to avoid screen 'Must be connected to a terminal.' error
# START HERE: add ssh to other compute_nodes, must use `ssh -t` to avoid screen 'Must be connected to a terminal.' error

# START HERE: detect when job/command/screen ends, change status and/or remove entry from job_running db table
# START HERE: detect when job/command/screen ends, change status and/or remove entry from job_running db table
# START HERE: detect when job/command/screen ends, change status and/or remove entry from job_running db table

    # MULTI-THREADED
    my string $screen_command;
    my string $screen_command_retval;
    my integer $screen_sessions_count = 1;  # force serialization loop below to execute at least once
    my string $screen_session_suffix;
    my string $screen_session;

    # serialize screen session suffix with random characters to ensure ease-of-lookup
    while ($screen_sessions_count) {
        $screen_session_suffix = $username . '_' . random_regex('[a-zA-Z0-9]{4}');
        print {*STDERR} '<<< DEBUG >>>: in Code::run_command() MULTI-THREADED, serialization check, have $screen_session_suffix = ', $screen_session_suffix, "\n";
 
#        $screen_command = 'screen -ls | grep -c ' . $screen_session_suffix;  # more efficient, but disabled in favor of full grep retval for use in WARNING below
        $screen_command = 'screen -ls | grep ' . $screen_session_suffix;
        print {*STDERR} '<<< DEBUG >>>: in Code::run_command() MULTI-THREADED, serialization check, about to run $screen_command = ', $screen_command, "\n";
        $screen_command_retval = `$screen_command 2>&1;`;
        print {*STDERR} '<<< DEBUG >>>: in Code::run_command() MULTI-THREADED, serialization check, have $CHILD_ERROR = ', $CHILD_ERROR, 
            ', $screen_command_retval = ', $screen_command_retval, "\n";
        # grep returns 1 if no match, false error triggered
#        if ($CHILD_ERROR) { 
#            $c->stash->{run_command}->{stdout_stderr} = 'ERROR: Failed to list current `screen` sessions for serialization check; ' . $screen_command_retval;
#            return;
#        }
 
#        $screen_sessions_count = string_to_integer($screen_command_retval);
        $screen_sessions_count = scalar (split /\n/, $screen_command_retval);
        print {*STDERR} '<<< DEBUG >>>: in Code::run_command() MULTI-THREADED, serialization check, have $screen_sessions_count = ', $screen_sessions_count, "\n";
        if ($screen_sessions_count > 0) { 
            print {*STDERR} '<<< DEBUG >>>: WARNING, in Code::run_command() MULTI-THREADED, SERIALIZATION COLLISION, have $screen_session_suffix = ', 
                $screen_session_suffix, ', have $screen_command_retval = ', $screen_command_retval, "\n";
        }
    }

    # start screen session
    $screen_command = 'screen -dmS ' . $screen_session_suffix;  # DELAYED_COMMAND_START 
#    $screen_command = 'screen -L -dmS ' . $screen_session_suffix;  # DELAYED_COMMAND_START WITH AUTO-LOGGING
#    $screen_command = 'screen -dmS ' . $screen_session_suffix . ' bash -c ' . q{'} . $command . q{'};  # IMMEDIATE_COMMAND_EXIT
#    $screen_command = 'screen -dmS ' . $screen_session_suffix . ' bash -c ' . q{'} . $command  . q{; read -p "JOB_COMPLETED__PRESS_ENTER_TO_CLOSE "} . q{'};
    print {*STDERR} '<<< DEBUG >>>: in Code::run_command() MULTI-THREADED, about to run $screen_command = ', $screen_command, "\n";
    $screen_command_retval = `$screen_command 2>&1;`;
    print {*STDERR} '<<< DEBUG >>>: in Code::run_command() MULTI-THREADED, have $CHILD_ERROR = ', $CHILD_ERROR, ', $screen_command_retval = ', $screen_command_retval, "\n";
    if ($CHILD_ERROR) { $c->stash->{run_command}->{stdout_stderr} = 'ERROR: Failed to start new `screen` session; ' . $screen_command_retval; return; }
    my string $status = q{screen_started};

    # get full screen session name
    $screen_command = 'screen -ls | grep ' . $screen_session_suffix;
    print {*STDERR} '<<< DEBUG >>>: in Code::run_command() MULTI-THREADED, about to run $screen_command = ', $screen_command, "\n";
    $screen_command_retval = `$screen_command 2>&1;`;
    print {*STDERR} '<<< DEBUG >>>: in Code::run_command() MULTI-THREADED, have $CHILD_ERROR = ', $CHILD_ERROR, ', $screen_command_retval = ', $screen_command_retval, "\n";
    # grep returns 1 if no match, false error triggered
    #if ($CHILD_ERROR) { $c->stash->{run_command}->{stdout_stderr} = 'ERROR: Failed to list current `screen` sessions; ' . $screen_command_retval; return; }

    # ensure exactly 1 session with this serialization is currently running
    $screen_sessions_count = scalar (split /\n/, $screen_command_retval);
    print {*STDERR} '<<< DEBUG >>>: in Code::run_command() MULTI-THREADED, have $screen_sessions_count = ', $screen_sessions_count, "\n";
    if ($screen_sessions_count == 0)
        { $c->stash->{run_command}->{stdout_stderr} = 'ERROR: Failed to find newly-started screen session ' . $screen_session_suffix; return; }
    elsif ($screen_sessions_count > 1)
        { $c->stash->{run_command}->{stdout_stderr} = 'ERROR: Failed to start uniquely-named screen session ' . $screen_session_suffix; return; }

    # parse out screen session name from retval
    $screen_session = $screen_command_retval;
    $screen_session =~ s/\s([^\s]+)\s.*/$1/gxms;  # strip away all non-session-name text
    print {*STDERR} '<<< DEBUG >>>: in Code::run_command() MULTI-THREADED, have $screen_session = ', $screen_session, "\n";

    # assemble logfile name
    # DEV NOTE, CORRELATION #cff01: screen logfile max path length is 70, must use OS symlink to shorten path
#    my string $screen_logfile = $ShinyCMS::ROOT_DIR . 'root/user_jobs/' . $username . '/' . $screen_session . '.log';
    my string $screen_logfile = '/srv/cloudff_user_jobs/' . $username . '/' . $screen_session . '.log';
    my string $screen_logfile_command;
    my string $screen_logfile_command_retval;

    # set logfile
    $screen_logfile_command = 'screen -r ' . $screen_session . ' -p0 -X colon "logfile ' . $screen_logfile . ' \015"';
#    $screen_logfile_command = 'screen -r ' . $screen_session . ' -p0 -X colon "logfile ' . $screen_logfile . '.%n \015"';  # with %n numeric suffix
    print {*STDERR} '<<< DEBUG >>>: in Code::run_command_input_ajax(), about to run $screen_logfile_command = ', $screen_logfile_command, "\n";
    $screen_logfile_command_retval = `$screen_logfile_command 2>&1;`;
    print {*STDERR} '<<< DEBUG >>>: in Code::run_command_input_ajax(), have $CHILD_ERROR = ', $CHILD_ERROR, ', $screen_logfile_command_retval = ', $screen_logfile_command_retval, "\n";
    if ($CHILD_ERROR) { $c->stash->{run_command}->{stdout_stderr} = 'ERROR: Failed to enable logging on `screen` session; ' . $screen_logfile_command_retval; return; }
    $status = 'command_logging';

    # set realtime logging
    $screen_logfile_command = 'screen -r ' . $screen_session . ' -p0 -X colon "logfile flush 0 \015"';  # flush output every 0 seconds, no delay
    print {*STDERR} '<<< DEBUG >>>: in Code::run_command_input_ajax(), about to run $screen_logfile_command = ', $screen_logfile_command, "\n";
    $screen_logfile_command_retval = `$screen_logfile_command 2>&1;`;
    print {*STDERR} '<<< DEBUG >>>: in Code::run_command_input_ajax(), have $CHILD_ERROR = ', $CHILD_ERROR, ', $screen_logfile_command_retval = ', $screen_logfile_command_retval, "\n";
    if ($CHILD_ERROR) { $c->stash->{run_command}->{stdout_stderr} = 'ERROR: Failed to enable logging on `screen` session; ' . $screen_logfile_command_retval; return; }
    $status = 'command_logging';

    # turn on logging
    $screen_logfile_command = 'screen -r ' . $screen_session . ' -p0 -X colon "log on \015"';
    print {*STDERR} '<<< DEBUG >>>: in Code::run_command_input_ajax(), about to run $screen_logfile_command = ', $screen_logfile_command, "\n";
    $screen_logfile_command_retval = `$screen_logfile_command 2>&1;`;
    print {*STDERR} '<<< DEBUG >>>: in Code::run_command_input_ajax(), have $CHILD_ERROR = ', $CHILD_ERROR, ', $screen_logfile_command_retval = ', $screen_logfile_command_retval, "\n";
    if ($CHILD_ERROR) { $c->stash->{run_command}->{stdout_stderr} = 'ERROR: Failed to enable logging on `screen` session; ' . $screen_logfile_command_retval; return; }
    $status = 'command_logging';

    # start command
    $screen_command = 'screen -r ' . $screen_session . ' -p0 -X stuff ' . q{'} . $command . q{ \015'};
    print {*STDERR} '<<< DEBUG >>>: in Code::run_command(), about to run $screen_command = ', $screen_command, "\n";
    $screen_command_retval = `$screen_command 2>&1;`;
    print {*STDERR} '<<< DEBUG >>>: in Code::run_command(), have $CHILD_ERROR = ', $CHILD_ERROR, ', $screen_command_retval = ', $screen_command_retval, "\n";
    if ($CHILD_ERROR) { $c->stash->{run_command}->{stdout_stderr} = 'ERROR: Failed to start job in `screen` session; ' . $screen_command_retval; return; }
    $status = 'command_running';

    # prepare job data for database
#    my integer $screen_pid = string_to_integer(shift (split /[.]/, $screen_session));
    my integer $screen_session_split = [split /[.]/, $screen_session];
    print {*STDERR} '<<< DEBUG >>>: in Code::run_command() MULTI-THREADED, have $screen_session_split = ', $screen_session_split, "\n";
    my integer $screen_session_split_shift = shift @{$screen_session_split};
    print {*STDERR} '<<< DEBUG >>>: in Code::run_command() MULTI-THREADED, have $screen_session_split_shift = ', $screen_session_split_shift, "\n";
    # DEV NOTE: use of string_to_integer() here w/out calling 'use RPerl' required refactoring of the RPerl type system, yay!  :-P
    my integer $screen_pid = string_to_integer($screen_session_split_shift);
    print {*STDERR} '<<< DEBUG >>>: in Code::run_command() MULTI-THREADED, have $screen_pid = ', $screen_pid, "\n";
    my integer $shiny_uid = $c->user->{_user}->{_column_data}->{id};
    my string $compute_nodes = '';  # START HERE, NEED FIX: set compute nodes & utilize via SSH!!!
    my integer $command_pid = -1;    

    # create entry in job_running database table
    my $job_running_entry = $c->model( 'DB::JobRunning' )->create({
        screen_pid => $screen_pid,
        shiny_uid => $shiny_uid,
        screen_session => $screen_session,
        screen_logfile => $screen_logfile,
        compute_nodes => $compute_nodes,
        command => $command,
        command_pid => $command_pid,
        output_line => 2,  # start reading second line, skip command sequence
        output_character => 1,  # start reading first character
        status => $status
    });

    print {*STDERR} '<<< DEBUG >>>: in Code::run_command() MULTI-THREADED, have $job_running_entry->{_column_data} = ', Dumper($job_running_entry->{_column_data}), "\n";

    # stash value(s)
    $c->stash->{run_command}->{pid} = $screen_pid;  # START HERE, NEED UPDATE: change to {screen_pid}???
    my integer $pid = $screen_pid;

    my string $stdout_stderr = q{};

#    print {*STDOUT} '<<< DEBUG >>>: in Code::run_command(), FINISH running $command = ', $command, "\n";

#    my $new_job_exit_status = $CHILD_ERROR >> 8;

#    print {*STDOUT} '<<< DEBUG >>>: in Code::run_command(), have $CHILD_ERROR = ', $CHILD_ERROR, "\n" ;
#    print {*STDOUT} '<<< DEBUG >>>: in Code::run_command(), have $new_job_exit_status = ', $new_job_exit_status, "\n" ;

    my boolean $stdout_stderr_content = ( ( defined $stdout_stderr ) and ( $stdout_stderr =~ m/[^\s]+/g ) );

    # stash command output
    if ( $stdout_stderr_content ) {
        print {*STDOUT} "\n", '<<< DEBUG >>>: in Code::run_command(), have [[[ NEW JOB COMMAND STDOUT & STDERR ]]]', "\n\n", $stdout_stderr, "\n" ;
        $c->stash->{run_command}->{stdout_stderr} = $stdout_stderr;
    }

#    if ($new_job_exit_status) {           # UNIX process exit status (AKA return code) not 0, error
#        $c->stash->{run_command}->{stdout_stderr} .= "\n\n" . '[[[ JOB ENDED WITH ERROR ]]]';
#    }
#    else {
#        $c->stash->{run_command}->{stdout_stderr} .= "\n\n" . '[[[ JOB ENDED WITH SUCCESS ]]]';
#    }

# KEYCODE

    # AJAX: generate code
    my CGI $cgi = CGI->new();
    my CGI::Ajax $cgi_ajax = new CGI::Ajax( run_command_input_ajax => 'run_command_input_ajax', skip_header => 1 );
    $cgi_ajax->skip_header(1);
    my string $run_command_output_ajax_html = <<EOHTML;
<html>
<body>
<input type="hidden" name="run_command_pid" id="run_command_pid" value="$pid">
<input type="hidden" name="run_command_input_param_update_request" id="run_command_input_param_update_request" value="">
<input autofocus type="text" name="run_command_input_param" id="run_command_input_param"
    onkeydown="
        handle_keydown(event);
    "
    onkeyup="
        run_command_input_ajax( ['run_command_pid', 'run_command_input_param'], [js_run_command_output_div_append] );
        document.getElementById('run_command_input_param').value = '';
    "
<br>

<script>
var key_codes = [];
key_codes[08] = '__B__';   // BACKSPACE
key_codes[09] = '__T__';   // TAB
key_codes[13] = '__E__';   // ENTER
//key_codes[16] = '__S__';   // SHIFT
//key_codes[17] = '__C__';   // CTRL
//key_codes[18] = '__A__';   // ALT
key_codes[27] = '__ES__';  // ESCAPE
//key_codes[32] = '__SP__';  // SPACE
//key_codes[33] = '__PU__';  // PAGE UP
//key_codes[34] = '__PD__';  // PAGE DOWN
key_codes[35] = '__EN__';  // END
key_codes[36] = '__HO__';  // HOME
key_codes[37] = '__AL__';  // ARROW LEFT
key_codes[38] = '__AU__';  // ARROW UP
key_codes[39] = '__AR__';  // ARROW RIGHT
key_codes[40] = '__AD__';  // ARROW DOWN
//key_codes[45] = '__I__';   // INSERT
key_codes[46] = '__D__';   // DELETE
//key_codes[XX] = '__X__';  // FOO

    function handle_keydown(e){
        if (key_codes[e.keyCode] !== undefined) {
            e.preventDefault();
            document.getElementById('run_command_input_param').value = key_codes[e.keyCode];
            run_command_input_ajax( ['run_command_pid', 'run_command_input_param'], [js_run_command_output_div_append] );
            document.getElementById('run_command_input_param').value = '';
            return;
        }

        // TEST TO DETERMINE UNKNOWN KEYCODES
//        if (1) {
//            e.preventDefault();
//            document.getElementById('run_command_input_param').value = '__CODE_' + e.keyCode + '__';
//            run_command_input_ajax( ['run_command_pid', 'run_command_input_param'], [js_run_command_output_div_append] );
//            document.getElementById('run_command_input_param').value = '';
//            return;
//        }
    }
</script>

</body>
</html>
EOHTML

    # AJAX: build & stash
    my string $output_ajax = $cgi_ajax->build_html($cgi, $run_command_output_ajax_html);
#    print {*STDOUT} '<<< DEBUG >>>: in Code::run_command(), have $output_ajax = ', "\n", $output_ajax, "\n\n";
    $c->stash->{run_command}->{output_ajax} = $output_ajax;
}


=head1 AUTHOR

Will Braswell <william.braswell@NOSPAM.autoparallel.com>

=head1 COPYRIGHT

NEED ADD COPYRIGHT

=head1 LICENSE

NEED ADD LICENSE

=cut

__PACKAGE__->meta->make_immutable;

1;

