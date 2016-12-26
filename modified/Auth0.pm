# [[[ PREPROCESSOR ]]]
# <<< TYPE_CHECKING: OFF >>>

# [[[ HEADER ]]]
#use RPerl;  # scans stuff it shouldn't, lots of delay & warnings
package ShinyCMS::Controller::Auth0;
use strict;
use warnings;
use RPerl::AfterSubclass;
our $VERSION = 0.002_000;

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

=head2 users_sign_in_auth0

Display the users/sign_in/auth0 AKA login AKA callback page.

=cut

sub users_sign_in_auth0 : Chained( 'base' ) : PathPart( 'sign_in/auth0' ) {
    my ( $self, $c ) = @ARG;
#    print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), received $self = ', "\n", Dumper($self), "\n\n";
#    print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), received $c = ', "\n", Dumper($c), "\n\n";
    print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0()', "\n";

    # set up stash
    $c->stash->{template} = 'auth0/sign_in.tt';
    $c->stash->{auth0_sign_in} = {};
    $c->stash->{auth0_sign_in}->{output} = q{};

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
#    print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), have $request = ', "\n", Dumper($request), "\n\n";
#    print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), have $env = ', "\n", Dumper($env), "\n\n";

    # accept parameters
    my $parameters = $request->parameters();
#    print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), have $parameters = ', Dumper($parameters), "\n";
    my $parameter_code = $parameters->{code};
    print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), have $parameter_code = ', $parameter_code, "\n";

    # Retrive the Plack::Middleware::DoormanAuth0 object
    my $doorman = $env->{'doorman.users.auth0'};
#    print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), have $doorman = ', Dumper($doorman), "\n";

    # Check sign-in status
    print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), about to call $doorman->is_sign_in...', "\n";
    if ($doorman->is_sign_in) {
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

            # NEED FIX SECURITY, CORRELATION #cff01: re-enable non-plaintext passwords in DB so that admin password is not stored unencrypted in DB
            # SECURITY: Attempt to authenticate the Shiny session WITH BLANK PLAINTEXT PASSWORD
            # this seems to be okay FOR NOW because the remaining /admin login form does not accept blank password fields, and that's a server-side check
            if ( $c->authenticate({ username => $shiny_username, password => q{} }) ) {
                print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), SUCCESS authenticating Shiny session, have $c->sessionid = ', Dumper($c->sessionid), "\n";
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
                print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), FAILURE authenticating Shiny session', "\n";
                $c->stash->{ error_msg } = "ERROR: Can't authenticate Shiny session.";
            }
        }
        # new Shiny account, use DoormanAuth0 user to create/register new Shiny user
        else
        {
            print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), FIRST TIME LOGIN, REGISTERING NEW SHINY ACCOUNT', "\n";
            print {*STDOUT} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), CHECK THIS!!!! have $doorman_user_data->{given_name} = ', $doorman_user_data->{given_name}, "\n";
            print {*STDOUT} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), CHECK THIS!!!! have $doorman_user_data->{family_name} = ', $doorman_user_data->{family_name}, "\n";





# THEN START HERE: check proper accessing of doorman first & last name above, then if set use as defaults for form text inputs below
# THEN START HERE: check proper accessing of doorman first & last name above, then if set use as defaults for form text inputs below
# THEN START HERE: check proper accessing of doorman first & last name above, then if set use as defaults for form text inputs below




            # check if the Doorman::Auth0 given_name is provided
            my string $doorman_given_name = q{};
            if ((exists $doorman_user_data->{given_name}) and 
                (defined $doorman_user_data->{given_name}) and 
                ($doorman_user_data->{given_name} ne q{})) {
                my string $doorman_given_name = $doorman_user_data->{given_name};

                # check if the Doorman::Auth0 given_name is valid
                if ( $doorman_given_name =~ m/\a-zA-Z/ ) {
                    # don't give an error, simply don't use
                    $doorman_given_name = q{};
#                    $c->flash->{ error_msg } = 'ERROR: Can not utilize GitHub given_name to create non-conflicting username, GitHub given_name may only contain letters; ' . q{'} . $doorman_given_name . q{'};
#                    $c->response->redirect( $c->uri_for( '/users', 'sign_in/auth0' ) );
#                    $c->detach;
                }
            }

            # check if the Doorman::Auth0 family_name is provided
            my string $doorman_family_name = q{};
            if ((exists $doorman_user_data->{family_name}) and 
                (defined $doorman_user_data->{family_name}) and 
                ($doorman_user_data->{family_name} ne q{})) {
                my string $doorman_family_name = $doorman_user_data->{family_name};

                # check if the Doorman::Auth0 family_name is valid
                if ( $doorman_family_name =~ m/\a-zA-Z/ ) {
                    # don't give an error, simply don't use
                    $doorman_family_name = q{};
#                    $c->flash->{ error_msg } = 'ERROR: Can not utilize GitHub family_name to create non-conflicting username, GitHub family_name may only contain letters; ' . q{'} . $doorman_family_name . q{'};
#                    $c->response->redirect( $c->uri_for( '/users', 'sign_in/auth0' ) );
#                    $c->detach;
                }
            }

            # HTML form to input/confirm the user's first & last names
            $c->stash->{auth0_sign_in}->{output} .=<<"EOL";
Please provide your real, legal first (given) and last (family) names, using only normal letters a-z and A-Z.<br>
Please do NOT use nicknames, special characters, commas, periods, etc.<br><br>
<form action='/users/sign_in/auth0' method='POST'>
    <span style="color: red">(*)</span> Real First Name: <input type='text' name='first_name' value='$doorman_given_name'><br>
    <span style="color: red">(*)</span> Real Last Name: <input type='text' name='last_name' value='$doorman_family_name'><br>
    <input type="submit" value="Submit">
</form>
EOL

            # get & validate first name parameter
            my string $first_name = q{};
            if ((exists $parameters->{first_name}) and 
                (defined $parameters->{first_name}) and
                ($parameters->{first_name}) ne q{}) {
                $first_name = $parameters->{first_name};
                print {*STDOUT} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), have parameter $first_name = ', $first_name, "\n";
                if ( $first_name =~ m/[^a-zA-Z]/g ) {
                    $c->flash->{ error_msg } = 'First names may only contain letters.';
#                    $c->response->redirect( $c->uri_for( '/users', 'sign_in/auth0' ) );
#                    $c->detach;
                    return;
                }
            }

            # get & validate last name parameter
            my string $last_name = q{};
            if ((exists $parameters->{last_name}) and 
                (defined $parameters->{last_name}) and
                ($parameters->{last_name}) ne q{}) {
                $last_name = $parameters->{last_name};
                print {*STDOUT} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), have parameter $last_name = ', $last_name, "\n";
                if ( $last_name =~ m/[^a-zA-Z]/g ) {
                    $c->flash->{ error_msg } = 'Last names may only contain letters.';
#                    $c->response->redirect( $c->uri_for( '/users', 'sign_in/auth0' ) );
#                    $c->detach;
                    return;
                }
            }

            # require both first & last name parameter
            if (($first_name eq q{}) or ($last_name eq q{})) {
                $c->flash->{ error_msg } = 'Both first and last name are required fields.';
#                $c->response->redirect( $c->uri_for( '/users', 'sign_in/auth0' ) );
#                $c->detach;
                return;
            }

            # Shiny username try #1: first letter of first name, whole last name, all lowercase
            my string $shiny_username = substr $first_name, 0, 1;
            $shiny_username .= $last_name;
            $shiny_username = lc $shiny_username;
            print {*STDOUT} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), have try #1 $shiny_username = ', $shiny_username, "\n";

            # check if the Shiny username is available, try #1
            my $user_exists = $c->model( 'DB::User' )->find({ username => $shiny_username });
            if ( $user_exists ) {
                # username try #1 not available, username already taken
                # check if the Doorman::Auth0 nickname is provided
                my string $doorman_nickname = q{};
                if ((exists $doorman_user_data->{nickname}) and 
                    (defined $doorman_user_data->{nickname}) and 
                    ($doorman_user_data->{nickname} ne q{})) {
                    my string $doorman_nickname = $doorman_user_data->{nickname};

                    # check if the Doorman::Auth0 nickname is valid
                    if ( $doorman_nickname =~ m/\W/ ) {
                        $c->flash->{ error_msg } = 'ERROR: Can not utilize GitHub nickname to create non-conflicting username, GitHub nickname may only contain letters, numbers and underscores; ' . q{'} . $doorman_nickname . q{'};
#                        $c->response->redirect( $c->uri_for( '/users', 'sign_in/auth0' ) );
#                        $c->detach;
                        return;
                    }
                }
                else {
                    $c->flash->{ error_msg } = 'ERROR: Can not utilize GitHub nickname to create non-conflicting username, GitHub nickname not provided.';
#                    $c->response->redirect( $c->uri_for( '/users', 'sign_in/auth0' ) );
#                    $c->detach;
                    return;
                }

                my $shiny_username_try1 = $shiny_username;
                $shiny_username .= '_' . $doorman_nickname;
                $shiny_username = lc $shiny_username;
                print {*STDOUT} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), have try #2 $shiny_username = ', $shiny_username, "\n";

                # check if the Shiny username is available, try #2
                $user_exists = $c->model( 'DB::User' )->find({ username => $shiny_username });
                if ( $user_exists ) {
                    # username try #2 not available, username already taken
                    $c->flash->{ error_msg } = 'ERROR: Can not create usernames ' . q{'} . $shiny_username_try1 . q{'} . ' or ' . 
                        q{'} . $shiny_username . q{'} . ', usernames already in use.';
#                    $c->response->redirect( $c->uri_for( '/users', 'sign_in/auth0' ) );
#                    $c->detach;
                    return;
                }
            }

            # check if the Shiny username is valid
            if ( $shiny_username =~ m/\W/ ) {
                $c->flash->{ error_msg } = 'ERROR: Username may only contain letters, numbers and underscores; ' . q{'} . $shiny_username . q{'};
#                $c->response->redirect( $c->uri_for( '/users', 'sign_in/auth0' ) );
#                $c->detach;
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
#                $c->response->redirect( $c->uri_for( '/users', 'sign_in/auth0' ) );
#                $c->detach;
                return;
            }

            # NEED FIX SECURITY, CORRELATION #cff01: re-enable non-plaintext passwords in DB so that admin password is not stored unencrypted in DB
            # SECURITY: create Shiny user WITH BLANK PLAINTEXT PASSWORD

            # create the now-validated user, variable $shiny_user already created but undef
            # use auto-generate Shiny username, BLANK PLAINTEXT PASSWORD, Doorman::Auth0 e-mail, and immediately active status 
            $shiny_user = $c->model( 'DB::User' )->create({
                username => $shiny_username,
                password => '',
                email    => $doorman_email,
                active   => 1,
            });

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
    print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), returned from $doorman->is_sign_in', "\n";
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

