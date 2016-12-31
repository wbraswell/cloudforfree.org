# [[[ PREPROCESSOR ]]]
# <<< TYPE_CHECKING: OFF >>>

# [[[ HEADER ]]]
#use RPerl;  # scans stuff it shouldn't, lots of delay & warnings
package ShinyCMS::Controller::Auth0;
use strict;
use warnings;
use RPerl::AfterSubclass;
our $VERSION = 0.003_000;

=head1 NAME

ShinyCMS::Controller::Auth0

=head1 DESCRIPTION

Controller for ShinyCMS authentication via Auth0.com.

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
use Plack::Request;
use RPerl::Config;
use Lingua::EN::NameParse qw(clean case_surname);

# [[[ CONSTANTS ]]]
has posts_per_page => (
    isa     => Int,
    is      => 'ro',
    default => 10,
);
# NEED FIX: remove Moose, replace w/ RPerl constant below
#use constant POSTS_PER_PAGE => my integer $TYPED_POSTS_PER_PAGE = 10;

# [[[ SUBROUTINES & OO METHODS ]]]

=head1 METHODS

=cut

=head2 base

Set up path and stash some useful info.

=cut

sub base : Chained( '/base' ) : PathPart( 'users' ) : CaptureArgs( 0 ) {
    my ( $self, $c ) = @ARG;
#    print {*STDERR} '<<< DEBUG >>>: in Auth0::base(), received $self = ', "\n", Dumper($self), "\n\n";
#    print {*STDERR} '<<< DEBUG >>>: in Auth0::base(), received $c = ', "\n", Dumper($c), "\n\n";
    print {*STDERR} '<<< DEBUG >>>: in Auth0::base()', "\n";

    # Stash the name of the controller
    $c->stash->{ controller } = 'Auth0';
}





sub do_login {
    (my $c, my $shiny_username) = @ARG;

    # SECURITY: Attempt to authenticate the Shiny session WITH BLANK ENCRYPTED PASSWORD
    # this seems to be okay FOR NOW because the remaining /admin login form does not accept blank password fields, and that's a server-side check
    if ( $c->authenticate({ username => $shiny_username, password => q{} }) ) {
        print {*STDERR} '<<< DEBUG >>>: in Auth0::do_login(), SUCCESS authenticating Shiny session, have $c->sessionid = ', Dumper($c->sessionid), "\n";
        # If successful, look for a basket on their old session and claim it
        my $basket = $c->model('DB::Basket')->search(
            {
                session => 'session:' . $c->sessionid,
                user    => undef,
            },
            {
                order_by => { -desc => 'created' },
                rows     => 1,
            }
        )->single;
        $basket->update({
            session => undef,
            user    => $c->user->id,
        }) if $basket and not $c->user->basket;
              
        # Log the IP address
        $c->user->user_ip_addresses->create({
            ip_address => $c->request->address,
        });
                
        # Then change their session ID to frustrate session hijackers
        # TODO: This breaks my logins - am I using it incorrectly?
        #$c->change_session_id;
                
        # Then bounce them back to the referring page or their profile
        if ( $c->request->param('redirect') 
                and $c->request->param('redirect') !~ m{user/login} ) {
            $c->response->redirect( $c->request->param( 'redirect' ) );
        }
        else {
            $c->response->redirect( $c->uri_for( '/user', $shiny_username ) );
        }
        return;
    }
    else {
        print {*STDERR} '<<< DEBUG >>>: in Auth0::do_login(), FAILURE authenticating Shiny session', "\n";
        $c->stash->{ error_msg } = "ERROR: Can't authenticate Shiny session.";
    }
}


=head2 users_sign_in_auth0

Display the users/sign_in/auth0 AKA login AKA callback page.

=cut

sub users_sign_in_auth0 : Chained( 'base' ) : PathPart( 'sign_in/auth0' ) {
    my ( $self, $c ) = @ARG;
#    print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), received $self = ', "\n", Dumper($self), "\n\n";
#    print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), received $c = ', "\n", Dumper($c), "\n\n";
    print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), top of subroutine', "\n";

    # set up stash
    $c->stash->{template} = 'auth0/sign_in.tt';
    $c->stash->{auth0_sign_in} = {};
    $c->stash->{auth0_sign_in}->{output} = q{};

    # TEMPORARY CODE: reset Shiny admin password, DOES NOT WORK CORRECTLY???
#    my $shiny_admin_user = $c->model( 'DB::User' )->find({ id => 1 });
#    $shiny_admin_user->update({ password => 'abc123', forgot_password => 0, });

    # TEMPORARY CODE: reset all Shiny users to BLANK ENCRYPTED PASSWORD
#    foreach my $i (1 .. 23) {
#        print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), TMP DEBUG LOOP, have $i = ', $i, "\n";
#        my $shiny_user_tmp = $c->model( 'DB::User' )->find({ id => $i });
#        my $shiny_user_tmp_data = $shiny_user_tmp->{_column_data};
#        print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), have PRE-RESET $shiny_user_tmp_data = ', Dumper($shiny_user_tmp_data), "\n";
#        $shiny_user_tmp->update({ password => q{}, forgot_password => 0, });
#        print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), have POST-RESET $shiny_user_tmp_data = ', Dumper($shiny_user_tmp_data), "\n";
#    }

    # get request & env
    my $request = $c->request();
    my $env = $request->env;
#    print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), have $request = ', "\n", Dumper($request), "\n\n";
#    print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), have $env = ', "\n", Dumper($env), "\n\n";

    # accept parameters
    my $parameters = $request->parameters();
#    print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), have $parameters = ', Dumper($parameters), "\n";

    # NEED ANSWER: is the Auth0 code not needed here?
#    my $parameter_code = $parameters->{code};
#    print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), have $parameter_code = ', $parameter_code, "\n";

    # Retrive the Plack::Middleware::DoormanAuth0 object
    my $doorman = $env->{'doorman.users.auth0'};
#    print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), have $doorman = ', Dumper($doorman), "\n";

    # Check sign-in status
    my $doorman_is_signed_in = $doorman->is_sign_in;
    if ($doorman_is_signed_in) {
        my string $doorman_email = $doorman->auth0_email;
#        $c->stash->{auth0_sign_in}->{output} .= 'SUCCESS! You are authenticated as: ' . $doorman_email;  # the won't see this due to fast redirect

        my $doorman_user_data = $env->{'psgix.session'}->{'doorman.users.auth0'};
        print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), have $doorman_user_data = ', Dumper($doorman_user_data), "\n";

        # does this Shiny user account already exist?
        my $shiny_user = $c->model( 'DB::User' )->find({ email => $doorman_email });
#        print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), have $shiny_user = ', Dumper($shiny_user), "\n";

        # existing Shiny account, log in DoormanAuth0 user as Shiny user
        if ( $shiny_user ) {
            if ( not $shiny_user->active ) {
                $c->flash->{ error_msg } = 'WARNING: This account has been disabled.';
                $c->response->redirect( $c->uri_for( '/' ) );
                return;
            }

            my $shiny_user_data = $shiny_user->{_column_data};
            print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), have $shiny_user_data = ', Dumper($shiny_user_data), "\n";
            my string $shiny_username = $shiny_user_data->{username};
            do_login($c, $shiny_username);
        }
        # new Shiny account, use DoormanAuth0 user to create/register new Shiny user
        else
        {
            print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), FIRST TIME LOGIN, REGISTERING NEW SHINY ACCOUNT', "\n";
 
            # check if the Doorman::Auth0 GitHub nickname is provided
            my string $doorman_nickname = q{};
            if ((exists $doorman_user_data->{nickname}) and 
                (defined $doorman_user_data->{nickname}) and 
                ($doorman_user_data->{nickname} ne q{})) {
                $doorman_nickname = $doorman_user_data->{nickname};

                # check if the Doorman::Auth0 nickname is valid
                if ( $doorman_nickname =~ m/\W/g ) {
                    $c->flash->{ error_msg } = 'ERROR: Invalid GitHub nickname received, GitHub nickname may only contain letters, numbers and underscores; ' . q{'} . $doorman_nickname . q{'};
                    return;
                }
            }
            else {
                $c->flash->{ error_msg } = 'ERROR: No GitHub nickname received.';
                return;
            }

            # check if the Doorman::Auth0 given_name is provided
            my string $doorman_given_name = q{};
            if ((exists $doorman_user_data->{given_name}) and 
                (defined $doorman_user_data->{given_name}) and 
                ($doorman_user_data->{given_name} ne q{})) {
                $doorman_given_name = $doorman_user_data->{given_name};
                print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), have $doorman_user_data->{given_name} = ', $doorman_user_data->{given_name}, "\n";

                # check if the Doorman::Auth0 given_name is valid
                if ( $doorman_given_name =~ m/[^a-zA-Z]/g ) {
                    # don't give an error, simply don't use
                    $doorman_given_name = q{};
                }
            }
            else { print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), DO NOT have $doorman_user_data->{given_name}', "\n"; }

            # check if the Doorman::Auth0 family_name is provided
            my string $doorman_family_name = q{};
            if ((exists $doorman_user_data->{family_name}) and 
                (defined $doorman_user_data->{family_name}) and 
                ($doorman_user_data->{family_name} ne q{})) {
                $doorman_family_name = $doorman_user_data->{family_name};
                print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), have $doorman_user_data->{family_name} = ', $doorman_user_data->{family_name}, "\n";

                # check if the Doorman::Auth0 family_name is valid
                if ( $doorman_family_name =~ m/[^a-zA-Z]/g ) {
                    # don't give an error, simply don't use
                    $doorman_family_name = q{};
                }
            }
            else { print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), DO NOT have $doorman_user_data->{family_name}', "\n"; }

            # check if the Doorman::Auth0 name is provided
            my string $doorman_name = q{};
            if ((exists $doorman_user_data->{name}) and 
                (defined $doorman_user_data->{name}) and 
                ($doorman_user_data->{name} ne q{})) {
                $doorman_name = $doorman_user_data->{name};
                print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), have $doorman_user_data->{name} = ', $doorman_user_data->{name}, "\n";

                # DO NOT check if the Doorman::Auth0 name is valid, leave it to name parser below
#                if ( $doorman_name =~ m/[^a-zA-Z]/g ) {
#                    # don't give an error, simply don't use
#                    $doorman_name = q{};
#                }
            }
            else { print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), DO NOT have $doorman_user_data->{name}', "\n"; }

            # parse Doorman::Auth0 name if provided
            my string $doorman_name_parsed_given_name = q{};
            my string $doorman_name_parsed_surname = q{};
            my %name_parser_args =
            (
                auto_clean      => 1,
                lc_prefix       => 1,
                initials        => 3,
                allow_reversed  => 0,
                joint_names     => 0,
                extended_titles => 0
            );
            my $name_parser = Lingua::EN::NameParse->new(%name_parser_args);
            my $name_parser_error = $name_parser->parse($doorman_name);
            if ( $name_parser_error )
            {
                print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), ERROR PARSING NAME, have $doorman_name = ', $doorman_name, ', have $name_parser_error = ', Dumper($name_parser_error), "\n";
            }
            else {
                print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), SUCCESS PARSING NAME, have $doorman_name = ', $doorman_name, ', have $name_parser->report = ', $name_parser->report, "\n";
                my %name_components = $name_parser->components;
                $doorman_name_parsed_given_name = $name_components{given_name_1};
                $doorman_name_parsed_surname = $name_components{surname_1};
                print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), SUCCESS PARSING NAME, have $doorman_name_parsed_given_name = ', $doorman_name_parsed_given_name, ', have $doorman_name_parsed_surname = ', $doorman_name_parsed_surname, "\n";
            }
            if (($doorman_given_name eq q{}) or ($doorman_family_name eq q{})) {
                if (($doorman_name_parsed_given_name ne q{}) and ($doorman_name_parsed_surname ne q{})) {
                    $doorman_given_name = $doorman_name_parsed_given_name;
                    $doorman_family_name = $doorman_name_parsed_surname;
                }
            }

            # check if the Doorman::Auth0 picture is provided
            my string $doorman_picture = q{};
            if ((exists $doorman_user_data->{picture}) and 
                (defined $doorman_user_data->{picture}) and 
                ($doorman_user_data->{picture} ne q{})) {
                $doorman_picture = $doorman_user_data->{picture};

                # check if the Doorman::Auth0 picture is valid
                if ( $doorman_picture !~ m/^https:\/\/avatars\d*\.githubusercontent\.com/g ) {
                    # don't give an error, simply don't use
                    $doorman_picture = q{};
                    print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), INVALID GITHUB PICTURE URL $doorman_picture = ', $doorman_picture, "\n";
                }
                else {
                    print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), VALID GITHUB PICTURE URL $doorman_picture = ', $doorman_picture, "\n";
                }
            }
            my string $doorman_picture_html = q{};
            if ($doorman_picture ne q{}) {
                $doorman_picture_html = 
                    q{<img class='outlined' align='left' width='30%' height='30%' style='margin-right: 20px' src='} . 
                    $doorman_picture . q{'><br>};
            }

            # HTML form to input/confirm the user's first & last names
            $c->stash->{auth0_sign_in}->{output} .=<<"EOL";
Please provide your real, legal first (given) and last (family) names, using only normal English letters a-z and A-Z.<br>
Please do NOT use middle names, nicknames, special characters, commas, periods, etc.<br><br>
<form action='/users/sign_in/auth0' method='POST'>
    $doorman_picture_html
    <span style="color: red">(*)</span> Real First Name: <input type='text' name='first_name' value='$doorman_given_name'><br>
    <span style="color: red">(*)</span> Real Last  Name: <input type='text' name='last_name' value='$doorman_family_name'><br>
    <span style="color: red">(*)</span> Real Location:   <input type='text' name='location'> (City, State, Country)<br><br>
    <textarea readonly style="width:60%; height:180px">
TERMS OF SERVICE:
By accessing or utilizing the CloudForFree.org computer services in any way, you agree to be bound by all of the following Terms Of Service:
- You are the person with the name and location provided above;
- You are 18 years of age or older;
- You will not use the services for illegal, unethical, or immoral purposes;
- You will continue to abide by the CloudForFree.org Terms Of Service as they are updated from time to time; and
- You will hold CloudForFree.org harmless in all affairs.
These services are being provided with absolutely no warranty whatsoever.
</textarea>
    <br><br>
    <b><i>NOTE: By clicking "I Understand & Agree" below, you confirm that you have read, understood, and agree to the Terms Of Service presented above.</i></b>
    <br><br>
    <input type="submit" value="I Understand & Agree">
</form>
EOL

            # get & validate first name parameter
            my string $first_name = q{};
            if ((exists $parameters->{first_name}) and 
                (defined $parameters->{first_name}) and
                ($parameters->{first_name}) ne q{}) {
                $first_name = $parameters->{first_name};
                print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), have parameter $first_name = ', $first_name, "\n";
                if ( $first_name =~ m/[^a-zA-Z]/g ) {
                    $c->flash->{ error_msg } = 'First names may only contain letters.';
                    return;
                }
            }

            # get & validate last name parameter
            my string $last_name = q{};
            if ((exists $parameters->{last_name}) and 
                (defined $parameters->{last_name}) and
                ($parameters->{last_name}) ne q{}) {
                $last_name = $parameters->{last_name};
                print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), have parameter $last_name = ', $last_name, "\n";
                if ( $last_name =~ m/[^a-zA-Z]/g ) {
                    $c->flash->{ error_msg } = 'Last names may only contain letters.';
                    return;
                }
            }

            # get & validate location parameter
            my string $location = q{};
            if ((exists $parameters->{location}) and 
                (defined $parameters->{location}) and
                ($parameters->{location}) ne q{}) {
                $location = $parameters->{location};
                print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), have parameter $location = ', $location, "\n";
                if ( $location =~ m/[^a-zA-Z0-9,.\- ]/g ) {
                    $c->flash->{ error_msg } = 'Locations may only contain letters, numbers, commas, periods, hyphens, and spaces.';
                    return;
                }
            }

            # require both first name & last name & location parameters
            if (($first_name eq q{}) or ($last_name eq q{}) or ($location eq q{})) {
                $c->flash->{ error_msg } = 'First name and last name and location are required fields.';
                return;
            }

            # Shiny username try #1: first letter of first name, whole last name, all lowercase
            my string $shiny_username = substr $first_name, 0, 1;
            $shiny_username .= $last_name;
            $shiny_username = lc $shiny_username;
            print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), have try #1 $shiny_username = ', $shiny_username, "\n";

            # check if the Shiny username is available, try #1
            my $user_exists = $c->model( 'DB::User' )->find({ username => $shiny_username });
            if ( $user_exists ) {
                # username try #1 not available, username already taken
                my $shiny_username_try1 = $shiny_username;
                $shiny_username .= '_' . $doorman_nickname;
                $shiny_username = lc $shiny_username;
                print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), have try #2 $shiny_username = ', $shiny_username, "\n";

                # check if the Shiny username is available, try #2
                $user_exists = $c->model( 'DB::User' )->find({ username => $shiny_username });
                if ( $user_exists ) {
                    # username try #2 not available, username already taken
                    $c->flash->{ error_msg } = 'ERROR: Can not create usernames ' . q{'} . $shiny_username_try1 . q{'} . ' or ' . 
                        q{'} . $shiny_username . q{'} . ', usernames already in use.';
                    return;
                }
            }

            # check if the Shiny username is valid
            if ( $shiny_username =~ m/\W/g ) {
                $c->flash->{ error_msg } = 'ERROR: Username may only contain letters, numbers and underscores; ' . q{'} . $shiny_username . q{'};
                return;
            }

            # check if the email address is valid
            my $doorman_email_valid = Email::Valid->address(
                -address  => $doorman_email,
                -mxcheck  => 1,
                -tldcheck => 1,
            );
            if ( not $doorman_email_valid ) {
                $c->flash->{ error_msg } = 'ERROR: You must set a valid email address in GitHub; ' . q{'} . $doorman_email . q{'};
                return;
            }

            # shared variables for running commands below
            my string $command;
            my string $command_retval;

            # SECURITY NEED FIX, CORRELATION #cff03: files are all owned by root user (?) and www-data group, need change to real *nix users & file ownership???
            # NEED UPGRADE: change below commands to pure-Perl versions, no backticks

            # copy GitHub profile pic as Shiny profile pic
            # create user profile pic directory, download GitHub profile pic
            my string $shiny_profile_pic = q{};
            if ($doorman_picture ne q{}) {
                $shiny_profile_pic = $shiny_username . '_profile_github.jpg';
                my string $shiny_user_profile_pics_dir = $ShinyCMS::ROOT_DIR . 'root/static/cms-uploads/user-profile-pics/' . $shiny_username . '/';

                $command = 'mkdir -p ' . $shiny_user_profile_pics_dir;
                print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), about to run $command = ', $command, "\n";
                $command_retval = `$command 2>&1;`;
                print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), have $CHILD_ERROR = ', $CHILD_ERROR, ', $command_retval = ', $command_retval, "\n";
                if ($CHILD_ERROR) { $c->stash->{auth0_sign_in}->{output} = 'ERROR: Failed to copy GitHub profile picture; ' . $command_retval; return; }

                $command = 'wget ' . $doorman_picture . ' -O ' . $shiny_user_profile_pics_dir . $shiny_profile_pic;
                print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), about to run $command = ', $command, "\n";
                $command_retval = `$command 2>&1;`;
                print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), have $CHILD_ERROR = ', $CHILD_ERROR, ', $command_retval = ', $command_retval, "\n";
                if ($CHILD_ERROR) { $c->stash->{auth0_sign_in}->{output} = 'ERROR: Failed to copy GitHub profile picture; ' . $command_retval; return; }

                $command = 'chgrp -R www-data ' . $shiny_user_profile_pics_dir;
                print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), about to run $command = ', $command, "\n";
                $command_retval = `$command 2>&1;`;
                print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), have $CHILD_ERROR = ', $CHILD_ERROR, ', $command_retval = ', $command_retval, "\n";
                if ($CHILD_ERROR) { $c->stash->{auth0_sign_in}->{output} = 'ERROR: Failed to copy GitHub profile picture; ' . $command_retval; return; }

                $command = 'chmod -R g+rwX ' . $shiny_user_profile_pics_dir;
                print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), about to run $command = ', $command, "\n";
                $command_retval = `$command 2>&1;`;
                print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), have $CHILD_ERROR = ', $CHILD_ERROR, ', $command_retval = ', $command_retval, "\n";
                if ($CHILD_ERROR) { $c->stash->{auth0_sign_in}->{output} = 'ERROR: Failed to copy GitHub profile picture; ' . $command_retval; return; }
            }

            # SECURITY NEED FIX, CORRELATION #cff03: files are all owned by root user (?) and www-data group, need change to real *nix users & file ownership???

            # create user files directory, give them their own copy of Learning RPerl exercises
            my string $shiny_user_files_dir = $ShinyCMS::ROOT_DIR . 'root/user_files/' . $shiny_username . '/';
            my string $learning_rperl_dir = $ShinyCMS::GITHUB_REPOS_DIR . 'rperl-latest/lib/RPerl/Learning/';

            $command = 'mkdir -p ' . $shiny_user_files_dir;
            print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), about to run $command = ', $command, "\n";
            $command_retval = `$command 2>&1;`;
            print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), have $CHILD_ERROR = ', $CHILD_ERROR, ', $command_retval = ', $command_retval, "\n";
            if ($CHILD_ERROR) { $c->stash->{auth0_sign_in}->{output} = 'ERROR: Failed to copy Learning RPerl source code files; ' . $command_retval; return; }

            $command = 'cp -a ' . $learning_rperl_dir . ' ' . $shiny_user_files_dir . 'LearningRPerl';
            print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), about to run $command = ', $command, "\n";
            $command_retval = `$command 2>&1;`;
            print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), have $CHILD_ERROR = ', $CHILD_ERROR, ', $command_retval = ', $command_retval, "\n";
            if ($CHILD_ERROR) { $c->stash->{auth0_sign_in}->{output} = 'ERROR: Failed to copy Learning RPerl source code files; ' . $command_retval; return; }

            $command = 'chgrp -R www-data ' . $shiny_user_files_dir;
            print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), about to run $command = ', $command, "\n";
            $command_retval = `$command 2>&1;`;
            print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), have $CHILD_ERROR = ', $CHILD_ERROR, ', $command_retval = ', $command_retval, "\n";
            if ($CHILD_ERROR) { $c->stash->{auth0_sign_in}->{output} = 'ERROR: Failed to copy Learning RPerl source code files; ' . $command_retval; return; }

            $command = 'chmod -R g+rwX ' . $shiny_user_files_dir;
            print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), about to run $command = ', $command, "\n";
            $command_retval = `$command 2>&1;`;
            print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), have $CHILD_ERROR = ', $CHILD_ERROR, ', $command_retval = ', $command_retval, "\n";
            if ($CHILD_ERROR) { $c->stash->{auth0_sign_in}->{output} = 'ERROR: Failed to copy Learning RPerl source code files; ' . $command_retval; return; }

            print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), before DB create(), have $doorman_email = ', $doorman_email, "\n";
            print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), before DB create(), have $shiny_username = ', $shiny_username, "\n";
            print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), before DB create(), have $first_name = ', $first_name, "\n";
            print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), before DB create(), have $last_name = ', $last_name, "\n";
            print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), before DB create(), have $shiny_profile_pic = ', $shiny_profile_pic, "\n";
            print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), about to call DB create() for new Shiny user...', "\n";

            # SECURITY: create Shiny user with BLANK ENCRYPTED PASSWORD

            # create the now-validated user, variable $shiny_user already created but undef
            # use auto-generate Shiny username, BLANK ENCRYPTED PASSWORD, Doorman::Auth0 e-mail, and immediately active status
            $shiny_user = $c->model( 'DB::User' )->create({
                email    => $doorman_email,
                github_nickname => $doorman_nickname,
                username => $shiny_username,
                password => q{},
                firstname => $first_name,
                surname => $last_name,
                location => $location,
                display_name => $first_name . ' ' . $last_name,
                profile_pic => $shiny_profile_pic,
                active   => 1,
            });

            print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), returned from DB create()', "\n";

            # log in new Shiny user
            do_login($c, $shiny_username);



# START HERE: fix terminal newline-on-enter, terminal timing loop & no spacebar needed, name tab based on file name, alert before overwriting file
# START HERE: fix terminal newline-on-enter, terminal timing loop & no spacebar needed, name tab based on file name, alert before overwriting file
# START HERE: fix terminal newline-on-enter, terminal timing loop & no spacebar needed, name tab based on file name, alert before overwriting file

# NEXT START HERE: profile pics resize, fix file save & add button & CTRL-S, run command options, A2::FM fix new file, A2::FM disable edit file, F2, F4
# NEXT START HERE: profile pics resize, fix file save & add button & CTRL-S, run command options, A2::FM fix new file, A2::FM disable edit file, F2, F4
# NEXT START HERE: profile pics resize, fix file save & add button & CTRL-S, run command options, A2::FM fix new file, A2::FM disable edit file, F2, F4













=DISABLE_NEW_ACCOUNT_CONFIRMATION_EMAIL

            # SECURITY: DO NOT create an entry in the confirmation table
            my $now = DateTime->now;
            my $code = generate_confirmation_code( $shiny_username, $c->request->address, $now->datetime );
            $user->confirmations->create({ code => $code });

            # SECURITY: DO NOT send out the confirmation email
            # NEED TEST: note sure if this even works, untested!
            my $site_name   = $c->config->{ site_name };
            my $site_url    = $c->uri_for( '/' );
            my $confirm_url = $c->uri_for( '/user', 'confirm', $code );
            my $body = <<EOT;
Somebody using this email address just registered on $site_name. 

If it was you, please click here to complete your registration:
$confirm_url
 
If you haven't recently registered on $site_name, please ignore this 
email - without confirmation, the account will remain locked, and will 
eventually be deleted.
 
-- 
$site_name
$site_url
EOT
            $c->stash->{ email_data } = {
                from    => $site_name .' <'. $c->config->{ site_email } .'>',
                to      => $doorman_email,
                subject => 'Confirm registration on '. $site_name,
                body    => $body,
            };
            $c->forward( $c->view( 'Email' ) );
=cut
        }
    }
    else {
        $c->stash->{auth0_sign_in}->{output} .= 'WARNING: Failed to log in using GitHub account via Auth0 authentication, please try again.';
    }
    print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), bottom of subroutine', "\n";
}


=head2 users_sign_out_auth0

Display the users/sign_out AKA logout page.

=cut


sub users_sign_out_auth0 : Chained( 'base' ) : PathPart( 'sign_out/auth0' ) {
    my ( $self, $c ) = @ARG;
#    print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_out_auth0(), received $self = ', "\n", Dumper($self), "\n\n";
#    print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_out_auth0(), received $c = ', "\n", Dumper($c), "\n\n";
    print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_out_auth0()', "\n";

    # set up stash
    $c->stash->{template} = 'auth0/sign_out.tt';
    $c->stash->{auth0_sign_out} = {};
    $c->stash->{auth0_sign_out}->{output} = '';

=DISABLE
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
    my $shiny_username = $c->user->{_user}->{_column_data}->{username};
=cut

    # get request & env
    my $request = $c->request();
    my $env = $request->env;
#    print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_out_auth0(), have $request = ', "\n", Dumper($request), "\n\n";
#    print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_out_auth0(), have $env = ', "\n", Dumper($env), "\n\n";

    # accept parameters
    my $parameters = $request->parameters();
#    print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_out_auth0(), have $parameters = ', Dumper($parameters), "\n";

    # NEED REMOVE: code not used here?
#    my $parameter_code = $parameters->{code};
#    print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_out_auth0(), have $parameter_code = ', $parameter_code, "\n";

    # Retrive the Plack::Middleware::DoormanAuth0 object
    my $doorman = $env->{'doorman.users.auth0'};
#    print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_out_auth0(), have $doorman = ', Dumper($doorman), "\n";

    # Check sign-in status
    print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_out_auth0(), about to call $doorman->is_sign_in...', "\n";
    if ($doorman->is_sign_in) {
        $c->stash->{auth0_sign_out}->{output} .= 'ERROR: Failed to sign out, you are still signed in as: ' . $doorman->auth0_email;
    }
    else {
        $c->stash->{auth0_sign_out}->{output} .= 'Successfully signed out, see you soon!';
    }
    print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_out_auth0(), returned from $doorman->is_sign_in', "\n";
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

