# IMPORTANT: if you delete this file your app will not work as expected.
use inc::Module::Install;
BEGIN {
	eval "use Module::Install::Catalyst";
	die "*** Please install Module::Install::Catalyst and run perl Makefile.PL again\n" if $@;
}

name 'ShinyCMS';
all_from 'lib/ShinyCMS.pm';

requires 'Catalyst::Runtime' => '5.80004';
requires 'Catalyst::Plugin::ConfigLoader';
requires 'Catalyst::Plugin::Static::Simple';
requires 'Catalyst::Action::RenderView';
requires 'parent';
requires 'Config::General';

requires (
	'Catalyst::Plugin::Authentication'           => '0',
	'Catalyst::Plugin::Session'                  => '0',
	'Catalyst::Plugin::Session::Store::DBIC'     => '0',
	'Catalyst::Plugin::Session::State::Cookie'   => '0',
	'Catalyst::Authentication::Realm::SimpleDB'  => '0',
	'Catalyst::View::TT'                         => '0',
	'Catalyst::View::Email'                      => '0',
	'Catalyst::TraitFor::Request::BrowserDetect' => '0',
	'CatalystX::RoleApplicator'                  => '0',
	'DBIx::Class::EncodedColumn'                 => '0',
	'DBIx::Class::Schema::Loader'                => '0',
	'DBIx::Class::TimeStamp'                     => '0',
	'Method::Signatures::Simple'                 => '0',
	'MooseX::NonMoose'                           => '0',
	'MooseX::MarkAsMethods'                      => '0',
	'XML::Feed'                                  => '0',
	'Captcha::reCAPTCHA'                         => '0',
	'HTML::Restrict'                             => '0',
	'Email::Sender'                              => '0.102360', # gets rid of -alias/-excludes warnings
	'Email::Valid'                               => '0',
	'Net::Domain::TLD'                           => '0',
	'Text::CSV::Simple'                          => '0',
	'File::Pid'                                  => '0',
	'HTML::TreeBuilder'                          => '0',

    # WBRASWELL 20161226 2016.361
    # Auth0
    'Plack::Middleware::DoormanAuth0'            => '0.10',
    'Lingua::EN::NameParse'                      => '1.36',
    # AJAX
    'CGI::Ajax'                                  => '0.707',
    # terminal emulation
#    'IO::Pty::Easy'                              => '0.10',
    'String::Random'                             => '0.29',
    'Term::VT102::Boundless'                     => '0.04',
    'Term::VT102::Incremental'                   => '0.05',
    # temp build files
    'File::Temp'                                 => '0.2304',
    # A2::FM file manager
    'Archive::Any'                               => '0.03',
    'CGI::Cookie'                                => '1.20',
    'File::NCopy'                                => '0.32',
    'File::Remove'                               => '0.20',
#    'Apache2::FileManager'                       => '0.30',
);

recommends (
	'Template::Plugin::Markdown'                 => '0',
	'FCGI'                                       => '0',
	'FCGI::ProcManager'                          => '0',
);

catalyst;

install_script glob( 'script/*.pl' );
auto_install;
WriteAll;

