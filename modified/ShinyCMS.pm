package ShinyCMS;

print {*STDERR} '<<< DEBUG >>>: top of ShinyCMS.pm', "\n";

# NEED FIX, CORRELATION #cff02: remove hard-coded absolute paths
our $GITHUB_REPOS_DIR = '/home/wbraswell/github_repos/';
our $ROOT_DIR = $GITHUB_REPOS_DIR . 'cloudforfree.org-latest/';

#print {*STDERR} '<<< DEBUG >>>: in ShinyCMS.pm, about to use ShinyCMS_dependencies', "\n";
#use ShinyCMS_dependencies;

print {*STDERR} '<<< DEBUG >>>: in ShinyCMS.pm, about to use Moose', "\n";

use Moose;
use namespace::autoclean;

print {*STDERR} '<<< DEBUG >>>: in ShinyCMS.pm, about to use Catalyst::Runtime', "\n";

use Catalyst::Runtime 5.80;

print {*STDERR} '<<< DEBUG >>>: in ShinyCMS.pm, about to use Catalyst', "\n";

use Catalyst qw/
	ConfigLoader
	Static::Simple
	
	Authentication
	
	Session
	Session::Store::DBIC
	Session::State::Cookie
/;

print {*STDERR} '<<< DEBUG >>>: in ShinyCMS.pm, about to use CatalystX::RoleApplicator', "\n";

use CatalystX::RoleApplicator;

print {*STDERR} '<<< DEBUG >>>: in ShinyCMS.pm, about to use Method::Signatures::Simple', "\n";

use Method::Signatures::Simple;

extends 'Catalyst';


our $VERSION = '0.007';
$VERSION = eval $VERSION;


# Configure the application.
#
# Note that settings in shinycms.conf (or other external
# configuration file that you set up manually) take precedence
# over this when using ConfigLoader. Thus configuration
# details given here can function as a default configuration,
# with an external configuration file acting as an override for
# local deployment.

print {*STDERR} '<<< DEBUG >>>: in ShinyCMS.pm, about to call config()', "\n";

__PACKAGE__->config(
    # Auth0: enable PSGI middleware
    'psgi_middleware', [
#        'Debug',  # SECURITY: publicly displays client secret!!!
        'Session::Cookie' => { secret => 'fake_secret' },
        'DoormanAuth0' => {
            root_url => 'http://cloudforfree.org',
            scope => 'users',
            auth0_domain => 'cloudforfree.auth0.com',
            auth0_client_secret => 'drY0Cbe0eL4IIBAb0OXK1yPz_5lZhwYx5qhoa3i-M8BYHifknS49G82qkeeQ2RSR',
            auth0_client_id     => 'JMwBFCjaelke73mE5HvLq7oTPOOQby9V'
        }
    ],
	name => 'ShinyCMS',
	# Configure DB sessions
	'Plugin::Session' => {
		dbic_class => 'DB::Session',
		expires    => 3600,
		# Stick the flash in the stash
		flash_to_stash => 1,
	},
	# Disable deprecated behaviour needed by old Catalyst applications
	disable_component_resolution_regex_fallback => 1,
    # Configure SimpleDB Authentication
    'Plugin::Authentication' => {
	    default => {
		    class           => 'SimpleDB',
		    user_model      => 'DB::User',
            # SECURITY & DoormanAuth0: comment following line to enable empty plaintext Shiny DB passwords
		    password_type   => 'self_check',
		    use_userdata_from_session => 1,
	    },
    },
	'Plugin::ConfigLoader' => {
		driver => {
			'General' => { -InterPolateVars => 1 },
		},
	},
);


# Set cookie domain to be wildcard (so it works on sub-domains too)
method finalize_config {
	__PACKAGE__->config(
		session => { cookie_domain => '.'.$self->config->{ domain } }
	);
	$self->next::method( @_ );
};


# Load browser detection trait (for detecting mobiles)
__PACKAGE__->apply_request_class_roles(
	'Catalyst::TraitFor::Request::BrowserDetect' 
);



print {*STDERR} '<<< DEBUG >>>: in ShinyCMS.pm, have __PACKAGE__ = ', __PACKAGE__, "\n";
print {*STDERR} '<<< DEBUG >>>: in ShinyCMS.pm, about to call setup()...', "\n";

# Start the application
__PACKAGE__->setup;

print {*STDERR} '<<< DEBUG >>>: in ShinyCMS.pm, returned from setup()', "\n";

=head1 NAME

ShinyCMS

=head1 SYNOPSIS

    script/shinycms_server.pl

=head1 DESCRIPTION

ShinyCMS is an open source CMS built in Perl using the Catalyst framework.

http://shinycms.org

http://catalystframework.org


=head1 SEE ALSO

L<ShinyCMS::Controller::Root>, L<Catalyst>

=head1 AUTHOR

Denny de la Haye <2014@denny.me>

=head1 LICENSE

This program is free software: you can redistribute it and/or modify it 
under the terms of the GNU Affero General Public License as published by 
the Free Software Foundation, either version 3 of the License, or (at your 
option) any later version.

You should have received a copy of the GNU Affero General Public License 
along with this program (see docs/AGPL-3.0.txt).  If not, see 
http://www.gnu.org/licenses/

=cut

#use Data::Dumper;
#print {*STDERR} '<<< DEBUG >>>: in ShinyCMS.pm, have %INC =', Dumper(\%INC), "\n";
#print {*STDERR} '<<< DEBUG >>>: in ShinyCMS.pm, BEGIN loaded packages', "\n\n";
#foreach my $module_filename (sort keys %INC) {
#    substr $module_filename, -3, 3, q{};  # trim .pm
#    $module_filename =~ s/\//::/g;  # convert / to ::
#    print '        use ', $module_filename, ';', "\n";
#}
#print {*STDERR} "\n", '<<< DEBUG >>>: in ShinyCMS.pm, END loaded packages', "\n";


print {*STDERR} '<<< DEBUG >>>: in ShinyCMS.pm, about to return 1', "\n";

1;

