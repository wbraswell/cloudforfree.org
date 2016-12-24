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


# START HERE: figure out how to get cloudforfree.org/auth0cb to load
# START HERE: figure out how to get cloudforfree.org/auth0cb to load
# START HERE: figure out how to get cloudforfree.org/auth0cb to load


sub base : Chained( '/base' ) : PathPart( 'auth0cb' ) : CaptureArgs( 0 ) {
    my ( $self, $c ) = @ARG;
#    print {*STDERR} '<<< DEBUG >>>: in Auth0::base(), received $self = ', "\n", Dumper($self), "\n\n";
#    print {*STDERR} '<<< DEBUG >>>: in Auth0::base(), received $c = ', "\n", Dumper($c), "\n\n";
    print {*STDERR} '<<< DEBUG >>>: in Auth0::auth0cb()', "\n";

    # Stash the name of the controller
    $c->stash->{ controller } = 'Auth0';
}

=head2 FOO

Display the FOO.

=cut

#sub FOO : Chained( 'base' ) : PathPart( 'FOO' ) {
sub auth0cb : Chained( 'base' ) : PathPart( '' ) {
    my ( $self, $c ) = @ARG;
#    print {*STDERR} '<<< DEBUG >>>: in Auth0::auth0cb(), received $self = ', "\n", Dumper($self), "\n\n";
#    print {*STDERR} '<<< DEBUG >>>: in Auth0::auth0cb(), received $c = ', "\n", Dumper($c), "\n\n";
    print {*STDERR} '<<< DEBUG >>>: in Auth0::auth0cb()', "\n";

    # set up stash
    $c->stash->{template} = 'auth0/callback.tt';
    $c->stash->{wrapper_disable} = 1;
    $c->stash->{auth0_callback} = {};
    $c->stash->{auth0_callback}->{output} = 'HOWDY FROM Auth0.pm!<br><br>' . "\n\n";

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
#    print {*STDERR} '<<< DEBUG >>>: in Auth0::auth0cb(), have $request = ', "\n", Dumper($request), "\n\n";
    print {*STDERR} '<<< DEBUG >>>: in Auth0::auth0cb(), have $env = ', "\n", Dumper($env), "\n\n";

    # accept parameters
    my $parameters = $request->parameters();
#    print {*STDERR} '<<< DEBUG >>>: in Auth0::auth0cb(), have $parameters = ', Dumper($parameters), "\n";
    my $parameter_code = $parameters->{code};
    print {*STDERR} '<<< DEBUG >>>: in Auth0::auth0cb(), have $parameter_code = ', $parameter_code, "\n";

    # Retrive the Plack::Middleware::DoormanAuth0 object
    my $doorman = $env->{'doorman.users.auth0'};
    print {*STDERR} '<<< DEBUG >>>: in Auth0::auth0cb(), have $doorman = ', Dumper($doorman), "\n";

    # Check sign-in status
    if ($doorman->is_sign_in) {
        $c->stash->{auth0_callback}->{output} .= 'SUCCESS!  You are signed in as: ' . $doorman->auth0_email;
    }
    else {
        $c->stash->{auth0_callback}->{output} .= 'PLEASE LOG IN';
    }
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

