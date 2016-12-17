# [[[ PREPROCESSOR ]]]
# <<< TYPE_CHECKING: OFF >>>

# [[[ HEADER ]]]
#use RPerl;  # scans CGI* & Catalyst* etc, lots of delay & warnings
package ShinyCMS::Controller::Code;
use strict;
use warnings;
use RPerl::AfterSubclass;
our $VERSION = 0.013_000;

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
use IPC::Open3;
use IO::Select;
use CGI qw(params);
use CGI::Ajax;
use Symbol qw(gensym); 
use Plack::Request;
use Apache2::FileManager::PSGI;
use Apache2::FileManager;
use rperloptions;
use RPerl::Config;

# [[[ CONSTANTS ]]]
has posts_per_page => (
    isa     => Int,
    is      => 'ro',
    default => 10,
);
# NEED FIX: remove Moose, replace w/ RPerl constant below
#use constant POSTS_PER_PAGE => my integer $TYPED_POSTS_PER_PAGE = 10;

# [[ PACKAGE VARIABLES ]]

our hashref $JOBS = {};
our hashref $KEY_CODES = {  # more listed here:  https://metacpan.org/pod/Term::ANSIMenu
    '__B__'  => [ "\x08", '__B__' ],   # BACKSPACE  "\b" does not work
    '__T__'  => [ "\x09", '__T__' ],   # TAB  "\t" does work
    '__E__'  => [ "\x0A",  '<br>'  ],   # ENTER  "\n" does work
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








=head1 METHODS

=cut

=head2 base

Set up path and stash some useful info.

=cut

sub base : Chained( '/base' ) : PathPart( 'code' ) : CaptureArgs( 0 ) {
    my ( $self, $c ) = @ARG;
    
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
#    print {*STDERR} '<<< DEBUG >>>: in Code::editor_file_manager_input_ajax(), received $self = ', "\n", Dumper($self), "\n\n";
#    print {*STDERR} '<<< DEBUG >>>: in Code::editor_file_manager_input_ajax(), received $c = ', "\n", Dumper($c), "\n\n";

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

    # require parameters (???)
    my $parameters = $request->parameters();
    print {*STDERR} '<<< DEBUG >>>: in Code::editor_file_manager_input_ajax(), have $parameters = ', Dumper($parameters), "\n";

=DISABLE do we need to check & accep params in this way?

    if (not ((exists $parameters->{editor_file_manager_input_param}) and (defined $parameters->{editor_file_manager_input_param}))) {
        croak("\n" . q{ERROR ECOEFMIAPA01, EDITOR FILE MANAGER INPUT AJAX, PARAMETERS: Missing HTML parameter 'editor_file_manager_input_param', should contain input for FOOOOO, croaking});
    }

    # accept input parameters
    my $input = $parameters->{editor_file_manager_input_param};
    print {*STDERR} '<<< DEBUG >>>: in Code::editor_file_manager_input_ajax(), have $input = ', q{'}, $input, q{'}, "\n";
=cut

    # Apache2::FileManager: variables
    my $shiny_username = $c->user->{_user}->{_column_data}->{username};
    my $document_root = '/home/wbraswell/public_html/cloudforfree.org-latest/root/user_files/' . $shiny_username . '/';
    my $request_wrapped_psgi;

    # Apache2::FileManager: override $r with $request_wrapped_psgi, thereby wrapping $r
    undef *Apache2::FileManager::r;
    *Apache2::FileManager::r = sub { return $request_wrapped_psgi };

    # Apache2::FileManager: create new $request_wrapped_psgi, generate HTML
    $request_wrapped_psgi = Apache2::FileManager::PSGI::new_from_psgi($request->env, $document_root);
    my $handler_retval = Apache2::FileManager->handler_noprint();

    # AJAX & Apache2::FileManager:
    # intercept calls to f.submit() for submitting the FileManager form data, which is used by all file & directory links plus most primary features;
    # replace with calls to editor_file_manager_input_ajax() for submitting the same FileManager form data via CGI::Ajax
    my $ajax_call_string = q{editor_file_manager_input_ajax( ['FILEMANAGER_curr_file', 'FILEMANAGER_curr_dir', 'FILEMANAGER_cmd', 'FILEMANAGER_arg', 'FILEMANAGER_last_select_all'], [js_editor_file_manager_div_update] );};
#    $ajax_call_string = q{alert('about to call editor_file_manager_input_ajax()...');} . "\n" . $ajax_call_string;
    $handler_retval =~ s/f\.submit\(\);/$ajax_call_string/gxms;

    # AJAX & Apache2::FileManager: intercept calls to window.document.FileManager which does not work inside W2UI layout, 
    # replace with window.document.forms.namedItem("FileManager")
    # hardcoded example, intercepted
    #window.document.FileManager
    # hardcoded example, replacement
    #window.document.forms.namedItem("FileManager")
    $handler_retval =~ s/window\.document\.FileManager/window\.document\.forms\.namedItem\('FileManager'\)/gxms;



    # START HERE: fix support for raw files below
    # START HERE: fix support for raw files below
    # START HERE: fix support for raw files below


    # AJAX & Apache2::FileManager: intercept links to raw files, replace with AJAX code
    # hardcoded example, intercepted
    #<A HREF="/FOO?nossi=1"
    #    TARGET=_blank>
    # hardcoded example, replacement
    #<A HREF=# onclick="
    #        var f=window.document.FileManager;
    #        f.FILEMANAGER_curr_file.value='FOO';
    #        editor_file_manager_input_ajax( ['FILEMANAGER_curr_file', 'FILEMANAGER_curr_dir', 'FILEMANAGER_cmd', 'FILEMANAGER_arg', 'FILEMANAGER_last_select_all'], [js_editor_file_manager_div_update] );
    #        return false;">
    $handler_retval =~ s/<A\s+HREF="(.+)"[\s\n\r]*TARGET=_blank>/
        <A HREF=\# onclick="
            var f=window.document.FileManager; 
            f.FILEMANAGER_curr_file.value='$1'; 
            $ajax_call_string
            return false;">
        /gxms;

    # AJAX & Apache2::FileManager: add FILEMANAGER_curr_file parameter
    # hardcoded example, find
    #    <INPUT TYPE=HIDDEN NAME=FILEMANAGER_curr_dir
    # hardcoded example, prepend
    #    <INPUT TYPE=HIDDEN NAME=FILEMANAGER_curr_file VALUE=''>
    my $handler_retval_tmp = q{};
    foreach my $handler_retval_line (split /\n/, $handler_retval) {
        if ($handler_retval_line eq '    <INPUT TYPE=HIDDEN NAME=FILEMANAGER_curr_dir') {
            $handler_retval_tmp .= q{    <INPUT TYPE=HIDDEN NAME=FILEMANAGER_curr_file VALUE=''>} . "\n";
        }
        $handler_retval_tmp .= $handler_retval_line . "\n";
    }
    $handler_retval = $handler_retval_tmp;

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
}


sub view_editor : Chained( 'base' ) : PathPart( 'editor' ) {
    my ( $self, $c ) = @ARG;
#    print {*STDERR} '<<< DEBUG >>>: in Code::view_editor(), received $self = ', "\n", Dumper($self), "\n\n";
#    print {*STDERR} '<<< DEBUG >>>: in Code::view_editor(), received $c = ', "\n", Dumper($c), "\n\n";

    my $request = $c->request();
    # NEED ANSWER: are we going to accept input parameters on this page?
#    my $parameters = $request->parameters();
#    if ((exists $parameters->{editor_ace_textarea}) and (defined $parameters->{editor_ace_textarea})) {
#        my $editor_ace_textarea = $parameters->{editor_ace_textarea};
#        print {*STDERR} '<<< DEBUG >>>: in Code::view_editor(), have parameter $editor_ace_textarea = ', "\n", Dumper($editor_ace_textarea), "\n\n";
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
#    print {*STDERR} '<<< DEBUG >>>: in Code::view_repos(), received $self = ', "\n", Dumper($self), "\n\n";
#    print {*STDERR} '<<< DEBUG >>>: in Code::view_repos(), received $c = ', "\n", Dumper($c), "\n\n";

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
#    print {*STDERR} '<<< DEBUG >>>: in Code::view_queue(), received $self = ', "\n", Dumper($self), "\n\n";
#    print {*STDERR} '<<< DEBUG >>>: in Code::view_queue(), received $c = ', "\n", Dumper($c), "\n\n";

    my $request = $c->request();
#    print {*STDERR} '<<< DEBUG >>>: in Code::view_queue(), have $request->param() = ', "\n", Dumper($request->param()), "\n\n";
#    print {*STDERR} '<<< DEBUG >>>: in Code::view_queue(), have $request->parameters() = ', "\n", Dumper($request->parameters()), "\n\n";

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
#    print {*STDERR} '<<< DEBUG >>>: in Code::syntax_check(), received $self = ', "\n", Dumper($self), "\n\n";
#    print {*STDERR} '<<< DEBUG >>>: in Code::syntax_check(), received $c = ', "\n", Dumper($c), "\n\n";

    my $request = $c->request();
#    print {*STDERR} '<<< DEBUG >>>: in Code::syntax_check(), have $request->param() = ', "\n", Dumper($request->param()), "\n\n";
#    print {*STDERR} '<<< DEBUG >>>: in Code::syntax_check(), have $request->parameters() = ', "\n", Dumper($request->parameters()), "\n\n";

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
    # append newline to avoid "ERROR ECOPAPC13, RPERL PARSER, PERL CRITIC VIOLATION: RPerl source code input file '/tmp/rperl_tempfileFOO.pl' does not end with newline character or line of all-whitespace characters, dying
    # append return character to avoid "ERROR ECOPAPC02, RPERL PARSER, PERL CRITIC VIOLATION: Perl::Critic::Policy::CodeLayout::RequireConsistentNewlines"
    my string $input_source_code = $parameters->{editor_ace_textarea} . "\r\n";
    print {*STDERR} '<<< DEBUG >>>: in Code::syntax_check(), have $input_source_code = ', "\n", $input_source_code, "\n\n";
    if ($input_source_code eq q{}) 
        { croak("\n" . q{ERROR ECOSCPA01, SYNTAX CHECK, PARAMETERS: Empty HTML parameter 'input_source_code', should contain source code to be syntax checked, croaking}); }

    if (not ((exists $parameters->{file_suffix}) and (defined $parameters->{file_suffix}))) 
        { croak("\n" . q{ERROR ECOSCPA02, SYNTAX CHECK, PARAMETERS: Missing HTML parameter 'file_suffix', should contain temporary file suffix, croaking}); }
    my string $file_suffix = $parameters->{file_suffix};
    print {*STDERR} '<<< DEBUG >>>: in Code::syntax_check(), have $file_suffix = ', $input_source_code, "\n";
    if ($file_suffix eq q{}) 
        { croak("\n" . q{ERROR ECOSCPA03, SYNTAX CHECK, PARAMETERS: Empty HTML parameter 'file_suffix', should contain temporary file suffix, croaking}); }

    # create temporary file
    my filehandleref $FILE_HANDLE_REFERENCE_TMP;
    my string $file_name_reference_tmp;
    ( $FILE_HANDLE_REFERENCE_TMP, $file_name_reference_tmp ) = tempfile( 'rperl_tempfileXXXX', SUFFIX => q{.} . $file_suffix, UNLINK => 1, TMPDIR => 1 );
    print {*STDERR} '<<< DEBUG >>>: in Code::syntax_check(), have $file_name_reference_tmp = ', q{'}, $file_name_reference_tmp, q{'}, "\n" ;
 
    # save source code into temporary file
    print {$FILE_HANDLE_REFERENCE_TMP} $input_source_code
        or croak("\nERROR ECOSCFI00, SYNTAX CHECK, FILE SYSTEM: Attempting to save new file '$file_name_reference_tmp', cannot write to file,\ncroaking: $OS_ERROR");
    close $FILE_HANDLE_REFERENCE_TMP 
        or croak("\nERROR ECOSCFI01, SYNTAX CHECK, FILE SYSTEM: Attempting to save new file '$file_name_reference_tmp', cannot close file,\ncroaking: $OS_ERROR");

    # create syntax check command string
    my string $syntax_check_command = 'rperl --Verbose --Debug --Warnings --mode ops=PERL --mode types=PERL --mode compile=GENERATE --mode parallel=OFF --mode execute=OFF ' . $file_name_reference_tmp;
#    my string $syntax_check_command = 'rperl -V -D -W -t -nop -noe ' . $file_name_reference_tmp;  # short-hand

    print {*STDERR} '<<< DEBUG >>>: in Code::syntax_check(), have $syntax_check_command = ', $syntax_check_command, "\n";

    my string $stdout_stderr = q{};

    print {*STDERR} '<<< DEBUG >>>: in Code::syntax_check(), START running $syntax_check_command = ', $syntax_check_command, "\n";

    # run syntax check command
    run3( $syntax_check_command, \undef, \$stdout_stderr, \$stdout_stderr );

    print {*STDERR} '<<< DEBUG >>>: in Code::syntax_check(), FINISH running $syntax_check_command = ', $syntax_check_command, "\n";

    my $syntax_check_exit_status = $CHILD_ERROR >> 8;

    print {*STDERR} '<<< DEBUG >>>: in Code::syntax_check(), have $CHILD_ERROR = ', $CHILD_ERROR, "\n" ;
    print {*STDERR} '<<< DEBUG >>>: in Code::syntax_check(), have $syntax_check_exit_status = ', $syntax_check_exit_status, "\n" ;

    my boolean $stdout_stderr_content = ( ( defined $stdout_stderr ) and ( $stdout_stderr =~ m/[^\s]+/g ) );

    # stash syntax check command output
    if ( $stdout_stderr_content ) {
        print {*STDERR} "\n", '<<< DEBUG >>>: in Code::syntax_check(), have [[[ SYNTAX CHECK COMMAND STDOUT & STDERR ]]]', "\n\n", $stdout_stderr, "\n" ;
        $c->stash->{syntax_check}->{stdout_stderr} = $stdout_stderr;
    }

    if ($syntax_check_exit_status) {               # UNIX process exit status (AKA return code) not 0, error
    # syntax errors cause error exit status, but we don't want to actually croak
#        if ( not $stdout_stderr_content ) {
#            print {*STDERR}  "\n", '[[[ SYNTAX CHECK COMMAND STDOUT & STDERR ARE BOTH EMPTY ]]]', "\n\n" ;
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


=head2 run_command

Run the RPerl command.

=cut

sub run_command_input_ajax : Chained( 'base' ) : PathPart( 'run_command_input_ajax' ) {
    my ( $self, $c ) = @ARG;
#    print {*STDERR} '<<< DEBUG >>>: in Code::run_command_input_ajax(), received $self = ', "\n", Dumper($self), "\n\n";
#    print {*STDERR} '<<< DEBUG >>>: in Code::run_command_input_ajax(), received $c = ', "\n", Dumper($c), "\n\n";

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
    if (not ((exists $parameters->{run_command_input_param}) and (defined $parameters->{run_command_input_param}))) {
        croak("\n" . q{ERROR ECORCIAPA01, RUN COMMAND INPUT AJAX, PARAMETERS: Missing HTML parameter 'run_command_input_param', should contain input for running command, croaking});
    }

    # accept pid & input parameters
    my $pid = $parameters->{run_command_pid};
    my $input = $parameters->{run_command_input_param};
    print {*STDERR} '<<< DEBUG >>>: in Code::run_command_input_ajax(), have $pid = ', $pid, "\n";
    print {*STDERR} '<<< DEBUG >>>: in Code::run_command_input_ajax(), have $input = ', q{'}, $input, q{'}, "\n";

    # load this PID's I/O stream handles from shared global $JOBS package (class) variable
#    print {*STDERR} '<<< DEBUG >>>: in Code::run_command_input_ajax(), have $Code::JOBS = ', "\n", Dumper($Code::JOBS), "\n\n";
    my filehandleref $COMMAND_IN = $Code::JOBS->{$pid}->{IN};
    my filehandleref $COMMAND_OUT = $Code::JOBS->{$pid}->{OUT};
    my filehandleref $COMMAND_ERR = $Code::JOBS->{$pid}->{ERR};

    # setup selector to collect available output
#    print {*STDERR} '<<< DEBUG >>>: in Code::run_command_input_ajax(), begin selector setup', "\n";
#    my IO::Select $selector = IO::Select->new();
#    $selector->add(*{$COMMAND_OUT}, *{$COMMAND_ERR});
#    print {*STDERR} '<<< DEBUG >>>: in Code::run_command_input_ajax(), end selector setup', "\n";

    # read available output before input has been provided
#    print {*STDERR} '<<< DEBUG >>>: in Code::run_command_input_ajax(), begin pre-input collection of output', "\n";
#    while (my @readable_filehandles = $selector->can_read(1)) {
##    my @readable_filehandles = $selector->can_read(0.1);
#        print {*STDERR} '<<< DEBUG >>>: in Code::run_command_input_ajax(), have @readable_filehandles = ', "\n", Dumper(\@readable_filehandles), "\n\n";
#        foreach my filehandleref $readable_filehandle (@readable_filehandles) {
#            print {*STDERR} '<<< DEBUG >>>: in Code::run_command_input_ajax(), have $readable_filehandle = ', Dumper($readable_filehandle), "\n";
#            if (fileno($readable_filehandle) == fileno(*{$COMMAND_ERR})) 
#                { $stdout_stderr .= scalar <$COMMAND_ERR>; }
#            else
#                { $stdout_stderr .= scalar <$COMMAND_OUT>; }
#            if (eof($readable_filehandle)) { $selector->remove($readable_filehandle); }
#        }
#    }
#    print {*STDERR} '<<< DEBUG >>>: in Code::run_command_input_ajax(), end pre-input collection of output', "\n";







    print {*STDERR} '<<< DEBUG >>>: in Code::run_command_input_ajax(), begin selector setup', "\n";
    my $selector = IO::Select->new();
    $selector->add($COMMAND_OUT);
    $selector->add($COMMAND_ERR);
    print {*STDERR} '<<< DEBUG >>>: in Code::run_command_input_ajax(), end selector setup', "\n";

    print {*STDERR} '<<< DEBUG >>>: in Code::run_command_input_ajax(), begin pre-input collection of output', "\n";
    my string $stdout_stderr_tmp = q{};
    while (my @readable_filehandles = $selector->can_read(0.1)) {
        print {*STDERR} '<<< DEBUG >>>: in Code::run_command_input_ajax(), have @readable_filehandles = ', "\n", Dumper(\@readable_filehandles);
        foreach my $readable_filehandle (@readable_filehandles) {
            if ($readable_filehandle == $COMMAND_OUT) {
                my $bytes_read = sysread($readable_filehandle, $stdout_stderr_tmp, 1024);
                if ($bytes_read == -1) {
                    warn("Error reading from child's STDOUT: $!\n");
                    $selector->remove($readable_filehandle);
                    next;
                }
                if ($bytes_read == 0) {
                    print("Child's STDOUT closed\n");
                    $selector->remove($readable_filehandle);
                    next;
                }
                printf("%4d bytes read from child's STDOUT\n", $bytes_read);
                $stdout_stderr .= $stdout_stderr_tmp;
            }
            elsif ($readable_filehandle == $COMMAND_ERR) {
                my $bytes_read = sysread($readable_filehandle, $stdout_stderr_tmp, 1024);
                if ($bytes_read == -1) {
                    warn("Error reading from child's STDERR: $!\n");
                    $selector->remove($readable_filehandle);
                    next;
                }
                if ($bytes_read == 0) {
                    print("Child's STDERR closed\n");
                    $selector->remove($readable_filehandle);
                    next;
                }
                printf("%4d bytes read from child's STDERR\n", $bytes_read);
                $stdout_stderr .= $stdout_stderr_tmp;
            }
        }
    }
    print {*STDERR} '<<< DEBUG >>>: in Code::run_command_input_ajax(), end pre-input collection of output', "\n";










    # strip trailing newline from input
    chomp $input;

    # START HERE: handle other special keys, clean up messy code
    # START HERE: handle other special keys, clean up messy code
    # START HERE: handle other special keys, clean up messy code
    
    # START HERE: then add JS cursor handler    http://stackoverflow.com/questions/512528/set-cursor-position-in-html-textbox
    # START HERE: then add JS cursor handler    http://stackoverflow.com/questions/512528/set-cursor-position-in-html-textbox
    # START HERE: then add JS cursor handler    http://stackoverflow.com/questions/512528/set-cursor-position-in-html-textbox

    # decode ENTER key if found, append input to output which has been read
    if (exists $KEY_CODES->{$input}) {
        $input = $KEY_CODES->{$input}->[0];
        $stdout_stderr = $KEY_CODES->{$input}->[1];
    }
    else {
        $stdout_stderr .= $input;
    }

    # actually print input value to input filehandle
#    print {*STDERR} '<<< DEBUG >>>: in Code::run_command_input_ajax(), begin input print', "\n";
#    print $COMMAND_IN $input;
#    print {*STDERR} '<<< DEBUG >>>: in Code::run_command_input_ajax(), end input print', "\n";

    print {*STDERR} '<<< DEBUG >>>: in Code::run_command_input_ajax(), begin input syswrite', "\n";
    syswrite $COMMAND_IN, $input;
    print {*STDERR} '<<< DEBUG >>>: in Code::run_command_input_ajax(), end input syswrite', "\n";

    # read available output after input has been provided
#    print {*STDERR} '<<< DEBUG >>>: in Code::run_command_input_ajax(), begin post-input collection of output', "\n";
#    $selector->remove(*{$COMMAND_OUT}, *{$COMMAND_ERR});
#    $selector->add(*{$COMMAND_OUT}, *{$COMMAND_ERR});
#    while (my @readable_filehandles = $selector->can_read(1)) {
##    my @readable_filehandles = $selector->can_read(0.1);
#        foreach my filehandleref $readable_filehandle (@readable_filehandles) {
#            if (fileno($readable_filehandle) == fileno(*{$COMMAND_ERR})) 
#                { $stdout_stderr .= scalar <$COMMAND_ERR>; }
#            else
#                { $stdout_stderr .= scalar <$COMMAND_OUT>; }
#            if (eof($readable_filehandle)) { $selector->remove($readable_filehandle); }
#        }
#    }
#    print {*STDERR} '<<< DEBUG >>>: in Code::run_command_input_ajax(), end post-input collection of output', "\n";

    print {*STDERR} '<<< DEBUG >>>: in Code::run_command_input_ajax(), about to return $stdout_stderr = ', $stdout_stderr, "\n";
    $c->stash->{run_command_input_ajax}->{output} = $stdout_stderr;
}


sub run_command : Chained( 'base' ) : PathPart( 'run_command' ) {
    my ( $self, $c ) = @ARG;
#    print {*STDERR} '<<< DEBUG >>>: in Code::run_command(), received $self = ', "\n", Dumper($self), "\n\n";
#    print {*STDERR} '<<< DEBUG >>>: in Code::run_command(), received $c = ', "\n", Dumper($c), "\n\n";

    my $request = $c->request();
#    print {*STDERR} '<<< DEBUG >>>: in Code::run_command(), have $request->param() = ', "\n", Dumper($request->param()), "\n\n";
#    print {*STDERR} '<<< DEBUG >>>: in Code::run_command(), have $request->parameters() = ', "\n", Dumper($request->parameters()), "\n\n";

    # set up stash
    $c->stash->{template} = 'code/view_run_command.tt';
    $c->stash->{run_command} = {};
    $c->stash->{run_command}->{title} = 'Run Command';
    $c->stash->{run_command}->{command} = q{};
    $c->stash->{run_command}->{pid} = q{};
    $c->stash->{run_command}->{stdout_stderr} = q{};
    $c->stash->{run_command}->{output_ajax} = q{};

    # require command parameter
    my $parameters = $request->parameters();
    if (not ((exists $parameters->{command}) and (defined $parameters->{command}))) {
        croak("\n" . q{ERROR ECORCPA00, RUN COMMAND, PARAMETERS: Missing HTML parameter 'command', should contain command to be run, croaking});
    }

    # accept command parameter
    my $command = $parameters->{command};
    print {*STDERR} '<<< DEBUG >>>: in Code::run_command(), have $command = ', $command, "\n";

    # SECURITY: disallow multiple commands, only allow 1 RPerl command!
    if ($command =~ m/[;|><]/) {
        print {*STDERR}  '<<< DEBUG >>>: SECURITY: in Code::run_command(), intercepted command with forbidden control character', "\n";
        $c->stash->{run_command}->{stdout_stderr} = 'ERROR: Command with forbidden control character ; or | or < or >';
        return;
    }

    # SECURITY: all commands must be RPerl commands!
    $command = 'rperl ' . $command;

    # store command back in stash to be displayed
    $c->stash->{run_command}->{command} = $command;

    # SECURITY: run all commands as www-data user; we automatically inherit PERL env vars, must explicitly inherit PATH env var
    # DEV NOTE: must use `unbuffer -p` to avoid 4K libc buffer min limit, which requires erroneous newline input before unblocking output
#    $command = q{su www-data -c "PATH=$PATH; set | grep TERM; unbuffer -p } . $command . q{"};
    $command = q{su www-data -c "PATH=$PATH; unbuffer -p } . $command . q{"};

    print {*STDERR} '<<< DEBUG >>>: in Code::run_command(), START running $command = ', $command, "\n";

    my string $stdout_stderr = q{};
    my filehandleref $COMMAND_IN;
    my filehandleref $COMMAND_OUT;
    my filehandleref $COMMAND_ERR = gensym;

    my integer $pid = open3($COMMAND_IN, $COMMAND_OUT, $COMMAND_ERR, $command);
    $c->stash->{run_command}->{pid} = $pid;
    $Code::JOBS->{$pid} = {};
    $Code::JOBS->{$pid}->{IN} = $COMMAND_IN;
    $Code::JOBS->{$pid}->{OUT} = $COMMAND_OUT;
    $Code::JOBS->{$pid}->{ERR} = $COMMAND_ERR;

    # handle child process exiting
#    $SIG{CHLD} = sub {
#        if (waitpid($pid, 0) > 0) {
#            print {*STDERR} 'CHILD PROCESS: exit status ', $CHILD_ERROR, ' on PID ', $pid, "\n";
#            close($Code::JOBS->{$pid}->{IN});
#            close($Code::JOBS->{$pid}->{OUT});
#            close($Code::JOBS->{$pid}->{ERR});
#        }
#    };

#    print {*COMMAND_IN} "23\n";  # NEED CHANGE: TEMP TEST INPUT
#    close(*{COMMAND_IN});

    # get initial output, up to first request for input or end of program
#    my IO::Select $selector = IO::Select->new();
#    $selector->add(*{COMMAND_ERR}, *{COMMAND_OUT});

##    while (my @readable_filehandles = $selector->can_read) {
#    my @readable_filehandles = $selector->can_read();
#        foreach my filehandleref $readable_filehandle (@readable_filehandles) {
#        if (fileno($readable_filehandle) == fileno(*{COMMAND_ERR})) 
#            { $stdout_stderr .= scalar <COMMAND_ERR>; }
#        else
#            { $stdout_stderr .= scalar <COMMAND_OUT>; }
#        if (eof($readable_filehandle)) { $selector->remove($readable_filehandle); }
#        }
##    }

#    close(*{COMMAND_OUT});
#    close(*{COMMAND_ERR});








#    print {*STDERR} '<<< DEBUG >>>: in Code::run_command(), FINISH running $command = ', $command, "\n";

#    my $new_job_exit_status = $CHILD_ERROR >> 8;

#    print {*STDERR} '<<< DEBUG >>>: in Code::run_command(), have $CHILD_ERROR = ', $CHILD_ERROR, "\n" ;
#    print {*STDERR} '<<< DEBUG >>>: in Code::run_command(), have $new_job_exit_status = ', $new_job_exit_status, "\n" ;

    my boolean $stdout_stderr_content = ( ( defined $stdout_stderr ) and ( $stdout_stderr =~ m/[^\s]+/g ) );

    # stash command output
    if ( $stdout_stderr_content ) {
        print {*STDERR} "\n", '<<< DEBUG >>>: in Code::run_command(), have [[[ NEW JOB COMMAND STDOUT & STDERR ]]]', "\n\n", $stdout_stderr, "\n" ;
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
Enter something: 
<input type="hidden" name="run_command_pid" id="run_command_pid" value="$pid">
<input type="text" name="run_command_input_param" id="run_command_input_param"
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
#    print {*STDERR} '<<< DEBUG >>>: in Code::run_command(), have $output_ajax = ', "\n", $output_ajax, "\n\n";
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

