# [[[ PREPROCESSOR ]]]
# <<< TYPE_CHECKING: OFF >>>

# [[[ HEADER ]]]
#use RPerl;  # scans stuff it shouldn't, lots of delay & warnings
package ShinyCMS::Controller::Auth0;
use strict;
use warnings;
use RPerl::AfterSubclass;
our $VERSION = 0.006_000;

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
    <span style="color: red">(*)</span> Real Name, First: <input type='text' name='first_name' value='$doorman_given_name'><br>
    <span style="color: red">(*)</span> Real Name, Last:  <input type='text' name='last_name' value='$doorman_family_name'><br>
    <span style="color: red">(*)</span> Real Location, City:    <input type='text' name='location_city'><br>
    <span style="color: red">(*)</span> Real Location, State:   <input type='text' name='location_state'><br>
    <span style="color: red">(*)</span> Real Location, Nation:  
        <select name='location_nation'>
            <option value="AF">Afghanistan</option>
            <option value="AX">Åland Islands</option>
            <option value="AL">Albania</option>
            <option value="DZ">Algeria</option>
            <option value="AS">American Samoa</option>
            <option value="AD">Andorra</option>
            <option value="AO">Angola</option>
            <option value="AI">Anguilla</option>
            <option value="AQ">Antarctica</option>
            <option value="AG">Antigua and Barbuda</option>
            <option value="AR">Argentina</option>
            <option value="AM">Armenia</option>
            <option value="AW">Aruba</option>
            <option value="AU">Australia</option>
            <option value="AT">Austria</option>
            <option value="AZ">Azerbaijan</option>
            <option value="BS">Bahamas</option>
            <option value="BH">Bahrain</option>
            <option value="BD">Bangladesh</option>
            <option value="BB">Barbados</option>
            <option value="BY">Belarus</option>
            <option value="BE">Belgium</option>
            <option value="BZ">Belize</option>
            <option value="BJ">Benin</option>
            <option value="BM">Bermuda</option>
            <option value="BT">Bhutan</option>
            <option value="BO">Bolivia, Plurinational State of</option>
            <option value="BQ">Bonaire, Sint Eustatius and Saba</option>
            <option value="BA">Bosnia and Herzegovina</option>
            <option value="BW">Botswana</option>
            <option value="BV">Bouvet Island</option>
            <option value="BR">Brazil</option>
            <option value="IO">British Indian Ocean Territory</option>
            <option value="BN">Brunei Darussalam</option>
            <option value="BG">Bulgaria</option>
            <option value="BF">Burkina Faso</option>
            <option value="BI">Burundi</option>
            <option value="KH">Cambodia</option>
            <option value="CM">Cameroon</option>
            <option value="CA">Canada</option>
            <option value="CV">Cape Verde</option>
            <option value="KY">Cayman Islands</option>
            <option value="CF">Central African Republic</option>
            <option value="TD">Chad</option>
            <option value="CL">Chile</option>
            <option value="CN">China</option>
            <option value="CX">Christmas Island</option>
            <option value="CC">Cocos (Keeling) Islands</option>
            <option value="CO">Colombia</option>
            <option value="KM">Comoros</option>
            <option value="CG">Congo</option>
            <option value="CD">Congo, the Democratic Republic of the</option>
            <option value="CK">Cook Islands</option>
            <option value="CR">Costa Rica</option>
            <option value="CI">Côte d'Ivoire</option>
            <option value="HR">Croatia</option>
            <option value="CU">Cuba</option>
            <option value="CW">Curaçao</option>
            <option value="CY">Cyprus</option>
            <option value="CZ">Czech Republic</option>
            <option value="DK">Denmark</option>
            <option value="DJ">Djibouti</option>
            <option value="DM">Dominica</option>
            <option value="DO">Dominican Republic</option>
            <option value="EC">Ecuador</option>
            <option value="EG">Egypt</option>
            <option value="SV">El Salvador</option>
            <option value="GQ">Equatorial Guinea</option>
            <option value="ER">Eritrea</option>
            <option value="EE">Estonia</option>
            <option value="ET">Ethiopia</option>
            <option value="FK">Falkland Islands (Malvinas)</option>
            <option value="FO">Faroe Islands</option>
            <option value="FJ">Fiji</option>
            <option value="FI">Finland</option>
            <option value="FR">France</option>
            <option value="GF">French Guiana</option>
            <option value="PF">French Polynesia</option>
            <option value="TF">French Southern Territories</option>
            <option value="GA">Gabon</option>
            <option value="GM">Gambia</option>
            <option value="GE">Georgia</option>
            <option value="DE">Germany</option>
            <option value="GH">Ghana</option>
            <option value="GI">Gibraltar</option>
            <option value="GR">Greece</option>
            <option value="GL">Greenland</option>
            <option value="GD">Grenada</option>
            <option value="GP">Guadeloupe</option>
            <option value="GU">Guam</option>
            <option value="GT">Guatemala</option>
            <option value="GG">Guernsey</option>
            <option value="GN">Guinea</option>
            <option value="GW">Guinea-Bissau</option>
            <option value="GY">Guyana</option>
            <option value="HT">Haiti</option>
            <option value="HM">Heard Island and McDonald Islands</option>
            <option value="VA">Holy See (Vatican City State)</option>
            <option value="HN">Honduras</option>
            <option value="HK">Hong Kong</option>
            <option value="HU">Hungary</option>
            <option value="IS">Iceland</option>
            <option value="IN">India</option>
            <option value="ID">Indonesia</option>
            <option value="IR">Iran, Islamic Republic of</option>
            <option value="IQ">Iraq</option>
            <option value="IE">Ireland</option>
            <option value="IM">Isle of Man</option>
            <option value="IL">Israel</option>
            <option value="IT">Italy</option>
            <option value="JM">Jamaica</option>
            <option value="JP">Japan</option>
            <option value="JE">Jersey</option>
            <option value="JO">Jordan</option>
            <option value="KZ">Kazakhstan</option>
            <option value="KE">Kenya</option>
            <option value="KI">Kiribati</option>
            <option value="KP">Korea, Democratic People's Republic of</option>
            <option value="KR">Korea, Republic of</option>
            <option value="KW">Kuwait</option>
            <option value="KG">Kyrgyzstan</option>
            <option value="LA">Lao People's Democratic Republic</option>
            <option value="LV">Latvia</option>
            <option value="LB">Lebanon</option>
            <option value="LS">Lesotho</option>
            <option value="LR">Liberia</option>
            <option value="LY">Libya</option>
            <option value="LI">Liechtenstein</option>
            <option value="LT">Lithuania</option>
            <option value="LU">Luxembourg</option>
            <option value="MO">Macao</option>
            <option value="MK">Macedonia, the former Yugoslav Republic of</option>
            <option value="MG">Madagascar</option>
            <option value="MW">Malawi</option>
            <option value="MY">Malaysia</option>
            <option value="MV">Maldives</option>
            <option value="ML">Mali</option>
            <option value="MT">Malta</option>
            <option value="MH">Marshall Islands</option>
            <option value="MQ">Martinique</option>
            <option value="MR">Mauritania</option>
            <option value="MU">Mauritius</option>
            <option value="YT">Mayotte</option>
            <option value="MX">Mexico</option>
            <option value="FM">Micronesia, Federated States of</option>
            <option value="MD">Moldova, Republic of</option>
            <option value="MC">Monaco</option>
            <option value="MN">Mongolia</option>
            <option value="ME">Montenegro</option>
            <option value="MS">Montserrat</option>
            <option value="MA">Morocco</option>
            <option value="MZ">Mozambique</option>
            <option value="MM">Myanmar</option>
            <option value="NA">Namibia</option>
            <option value="NR">Nauru</option>
            <option value="NP">Nepal</option>
            <option value="NL">Netherlands</option>
            <option value="NC">New Caledonia</option>
            <option value="NZ">New Zealand</option>
            <option value="NI">Nicaragua</option>
            <option value="NE">Niger</option>
            <option value="NG">Nigeria</option>
            <option value="NU">Niue</option>
            <option value="NF">Norfolk Island</option>
            <option value="MP">Northern Mariana Islands</option>
            <option value="NO">Norway</option>
            <option value="OM">Oman</option>
            <option value="PK">Pakistan</option>
            <option value="PW">Palau</option>
            <option value="PS">Palestinian Territory, Occupied</option>
            <option value="PA">Panama</option>
            <option value="PG">Papua New Guinea</option>
            <option value="PY">Paraguay</option>
            <option value="PE">Peru</option>
            <option value="PH">Philippines</option>
            <option value="PN">Pitcairn</option>
            <option value="PL">Poland</option>
            <option value="PT">Portugal</option>
            <option value="PR">Puerto Rico</option>
            <option value="QA">Qatar</option>
            <option value="RE">Réunion</option>
            <option value="RO">Romania</option>
            <option value="RU">Russian Federation</option>
            <option value="RW">Rwanda</option>
            <option value="BL">Saint Barthélemy</option>
            <option value="SH">Saint Helena, Ascension and Tristan da Cunha</option>
            <option value="KN">Saint Kitts and Nevis</option>
            <option value="LC">Saint Lucia</option>
            <option value="MF">Saint Martin (French part)</option>
            <option value="PM">Saint Pierre and Miquelon</option>
            <option value="VC">Saint Vincent and the Grenadines</option>
            <option value="WS">Samoa</option>
            <option value="SM">San Marino</option>
            <option value="ST">Sao Tome and Principe</option>
            <option value="SA">Saudi Arabia</option>
            <option value="SN">Senegal</option>
            <option value="RS">Serbia</option>
            <option value="SC">Seychelles</option>
            <option value="SL">Sierra Leone</option>
            <option value="SG">Singapore</option>
            <option value="SX">Sint Maarten (Dutch part)</option>
            <option value="SK">Slovakia</option>
            <option value="SI">Slovenia</option>
            <option value="SB">Solomon Islands</option>
            <option value="SO">Somalia</option>
            <option value="ZA">South Africa</option>
            <option value="GS">South Georgia and the South Sandwich Islands</option>
            <option value="SS">South Sudan</option>
            <option value="ES">Spain</option>
            <option value="LK">Sri Lanka</option>
            <option value="SD">Sudan</option>
            <option value="SR">Suriname</option>
            <option value="SJ">Svalbard and Jan Mayen</option>
            <option value="SZ">Swaziland</option>
            <option value="SE">Sweden</option>
            <option value="CH">Switzerland</option>
            <option value="SY">Syrian Arab Republic</option>
            <option value="TW">Taiwan, Province of China</option>
            <option value="TJ">Tajikistan</option>
            <option value="TZ">Tanzania, United Republic of</option>
            <option value="TH">Thailand</option>
            <option value="TL">Timor-Leste</option>
            <option value="TG">Togo</option>
            <option value="TK">Tokelau</option>
            <option value="TO">Tonga</option>
            <option value="TT">Trinidad and Tobago</option>
            <option value="TN">Tunisia</option>
            <option value="TR">Turkey</option>
            <option value="TM">Turkmenistan</option>
            <option value="TC">Turks and Caicos Islands</option>
            <option value="TV">Tuvalu</option>
            <option value="UG">Uganda</option>
            <option value="UA">Ukraine</option>
            <option value="AE">United Arab Emirates</option>
            <option value="GB">United Kingdom</option>
            <option value="US" selected="selected">United States of America</option>
            <option value="UM">United States Minor Outlying Islands</option>
            <option value="UY">Uruguay</option>
            <option value="UZ">Uzbekistan</option>
            <option value="VU">Vanuatu</option>
            <option value="VE">Venezuela, Bolivarian Republic of</option>
            <option value="VN">Viet Nam</option>
            <option value="VG">Virgin Islands, British</option>
            <option value="VI">Virgin Islands, U.S.</option>
            <option value="WF">Wallis and Futuna</option>
            <option value="EH">Western Sahara</option>
            <option value="YE">Yemen</option>
            <option value="ZM">Zambia</option>
            <option value="ZW">Zimbabwe</option>
        </select>
        <br><br>
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





            # get & validate location_city parameter
            my string $location_city = q{};
            if ((exists $parameters->{location_city}) and 
                (defined $parameters->{location_city}) and
                ($parameters->{location_city}) ne q{}) {
                $location_city = $parameters->{location_city};
                print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), have parameter $location_city = ', $location_city, "\n";
                if ( $location_city =~ m/[^a-zA-Z0-9,.\- ]/g ) {
                    $c->flash->{ error_msg } = 'Location cities may only contain letters, numbers, commas, periods, hyphens, and spaces.';
                    return;
                }
            }

            # get & validate location_state parameter
            my string $location_state = q{};
            if ((exists $parameters->{location_state}) and 
                (defined $parameters->{location_state}) and
                ($parameters->{location_state}) ne q{}) {
                $location_state = $parameters->{location_state};
                print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), have parameter $location_state = ', $location_state, "\n";
                if ( $location_state =~ m/[^a-zA-Z0-9,.\- ]/g ) {
                    $c->flash->{ error_msg } = 'Location states may only contain letters, numbers, commas, periods, hyphens, and spaces.';
                    return;
                }
            }

            # all nation codes, w/out commas so we can use commas when combining "city, state, nation"
            my string_hashref $nation_codes = {
                'AF' => q{Afghanistan},
                'AX' => q{Åland Islands},
                'AL' => q{Albania},
                'DZ' => q{Algeria},
                'AS' => q{American Samoa},
                'AD' => q{Andorra},
                'AO' => q{Angola},
                'AI' => q{Anguilla},
                'AQ' => q{Antarctica},
                'AG' => q{Antigua and Barbuda},
                'AR' => q{Argentina},
                'AM' => q{Armenia},
                'AW' => q{Aruba},
                'AU' => q{Australia},
                'AT' => q{Austria},
                'AZ' => q{Azerbaijan},
                'BS' => q{Bahamas},
                'BH' => q{Bahrain},
                'BD' => q{Bangladesh},
                'BB' => q{Barbados},
                'BY' => q{Belarus},
                'BE' => q{Belgium},
                'BZ' => q{Belize},
                'BJ' => q{Benin},
                'BM' => q{Bermuda},
                'BT' => q{Bhutan},
#                'BO' => q{Bolivia, Plurinational State of},
                'BO' => q{Bolivia},
#                'BQ' => q{Bonaire, Sint Eustatius and Saba},
                'BQ' => q{Bonaire},
                'BA' => q{Bosnia and Herzegovina},
                'BW' => q{Botswana},
                'BV' => q{Bouvet Island},
                'BR' => q{Brazil},
                'IO' => q{British Indian Ocean Territory},
                'BN' => q{Brunei Darussalam},
                'BG' => q{Bulgaria},
                'BF' => q{Burkina Faso},
                'BI' => q{Burundi},
                'KH' => q{Cambodia},
                'CM' => q{Cameroon},
                'CA' => q{Canada},
                'CV' => q{Cape Verde},
                'KY' => q{Cayman Islands},
                'CF' => q{Central African Republic},
                'TD' => q{Chad},
                'CL' => q{Chile},
                'CN' => q{China},
                'CX' => q{Christmas Island},
                'CC' => q{Cocos (Keeling) Islands},
                'CO' => q{Colombia},
                'KM' => q{Comoros},
                'CG' => q{Congo},
#                'CD' => q{Congo, the Democratic Republic of the},
                'CD' => q{The Democratic Republic of the Congo},
                'CK' => q{Cook Islands},
                'CR' => q{Costa Rica},
                'CI' => q{Côte d'Ivoire},
                'HR' => q{Croatia},
                'CU' => q{Cuba},
                'CW' => q{Curaçao},
                'CY' => q{Cyprus},
                'CZ' => q{Czech Republic},
                'DK' => q{Denmark},
                'DJ' => q{Djibouti},
                'DM' => q{Dominica},
                'DO' => q{Dominican Republic},
                'EC' => q{Ecuador},
                'EG' => q{Egypt},
                'SV' => q{El Salvador},
                'GQ' => q{Equatorial Guinea},
                'ER' => q{Eritrea},
                'EE' => q{Estonia},
                'ET' => q{Ethiopia},
                'FK' => q{Falkland Islands (Malvinas)},
                'FO' => q{Faroe Islands},
                'FJ' => q{Fiji},
                'FI' => q{Finland},
                'FR' => q{France},
                'GF' => q{French Guiana},
                'PF' => q{French Polynesia},
                'TF' => q{French Southern Territories},
                'GA' => q{Gabon},
                'GM' => q{Gambia},
                'GE' => q{Georgia},
                'DE' => q{Germany},
                'GH' => q{Ghana},
                'GI' => q{Gibraltar},
                'GR' => q{Greece},
                'GL' => q{Greenland},
                'GD' => q{Grenada},
                'GP' => q{Guadeloupe},
                'GU' => q{Guam},
                'GT' => q{Guatemala},
                'GG' => q{Guernsey},
                'GN' => q{Guinea},
                'GW' => q{Guinea-Bissau},
                'GY' => q{Guyana},
                'HT' => q{Haiti},
                'HM' => q{Heard Island and McDonald Islands},
                'VA' => q{Holy See (Vatican City State)},
                'HN' => q{Honduras},
                'HK' => q{Hong Kong},
                'HU' => q{Hungary},
                'IS' => q{Iceland},
                'IN' => q{India},
                'ID' => q{Indonesia},
#                'IR' => q{Iran, Islamic Republic of},
                'IR' => q{Iran},
                'IQ' => q{Iraq},
                'IE' => q{Ireland},
                'IM' => q{Isle of Man},
                'IL' => q{Israel},
                'IT' => q{Italy},
                'JM' => q{Jamaica},
                'JP' => q{Japan},
                'JE' => q{Jersey},
                'JO' => q{Jordan},
                'KZ' => q{Kazakhstan},
                'KE' => q{Kenya},
                'KI' => q{Kiribati},
#                'KP' => q{Korea, Democratic People's Republic of},
                'KP' => q{Democratic People's Republic of Korea},
#                'KR' => q{Korea, Republic of},
                'KR' => q{Republic of Korea},
                'KW' => q{Kuwait},
                'KG' => q{Kyrgyzstan},
                'LA' => q{Lao People's Democratic Republic},
                'LV' => q{Latvia},
                'LB' => q{Lebanon},
                'LS' => q{Lesotho},
                'LR' => q{Liberia},
                'LY' => q{Libya},
                'LI' => q{Liechtenstein},
                'LT' => q{Lithuania},
                'LU' => q{Luxembourg},
                'MO' => q{Macao},
#                'MK' => q{Macedonia, the former Yugoslav Republic of},
                'MK' => q{Macedonia},
                'MG' => q{Madagascar},
                'MW' => q{Malawi},
                'MY' => q{Malaysia},
                'MV' => q{Maldives},
                'ML' => q{Mali},
                'MT' => q{Malta},
                'MH' => q{Marshall Islands},
                'MQ' => q{Martinique},
                'MR' => q{Mauritania},
                'MU' => q{Mauritius},
                'YT' => q{Mayotte},
                'MX' => q{Mexico},
#                'FM' => q{Micronesia, Federated States of},
                'FM' => q{Micronesia},
#                'MD' => q{Moldova, Republic of},
                'MD' => q{Moldova},
                'MC' => q{Monaco},
                'MN' => q{Mongolia},
                'ME' => q{Montenegro},
                'MS' => q{Montserrat},
                'MA' => q{Morocco},
                'MZ' => q{Mozambique},
                'MM' => q{Myanmar},
                'NA' => q{Namibia},
                'NR' => q{Nauru},
                'NP' => q{Nepal},
                'NL' => q{Netherlands},
                'NC' => q{New Caledonia},
                'NZ' => q{New Zealand},
                'NI' => q{Nicaragua},
                'NE' => q{Niger},
                'NG' => q{Nigeria},
                'NU' => q{Niue},
                'NF' => q{Norfolk Island},
                'MP' => q{Northern Mariana Islands},
                'NO' => q{Norway},
                'OM' => q{Oman},
                'PK' => q{Pakistan},
                'PW' => q{Palau},
#                'PS' => q{Palestinian Territory, Occupied},
                'PS' => q{Palestinian Territory},
                'PA' => q{Panama},
                'PG' => q{Papua New Guinea},
                'PY' => q{Paraguay},
                'PE' => q{Peru},
                'PH' => q{Philippines},
                'PN' => q{Pitcairn},
                'PL' => q{Poland},
                'PT' => q{Portugal},
                'PR' => q{Puerto Rico},
                'QA' => q{Qatar},
                'RE' => q{Réunion},
                'RO' => q{Romania},
                'RU' => q{Russian Federation},
                'RW' => q{Rwanda},
                'BL' => q{Saint Barthélemy},
#                'SH' => q{Saint Helena, Ascension and Tristan da Cunha},
                'SH' => q{Saint Helena},
                'KN' => q{Saint Kitts and Nevis},
                'LC' => q{Saint Lucia},
                'MF' => q{Saint Martin (French part)},
                'PM' => q{Saint Pierre and Miquelon},
                'VC' => q{Saint Vincent and the Grenadines},
                'WS' => q{Samoa},
                'SM' => q{San Marino},
                'ST' => q{Sao Tome and Principe},
                'SA' => q{Saudi Arabia},
                'SN' => q{Senegal},
                'RS' => q{Serbia},
                'SC' => q{Seychelles},
                'SL' => q{Sierra Leone},
                'SG' => q{Singapore},
                'SX' => q{Sint Maarten (Dutch part)},
                'SK' => q{Slovakia},
                'SI' => q{Slovenia},
                'SB' => q{Solomon Islands},
                'SO' => q{Somalia},
                'ZA' => q{South Africa},
                'GS' => q{South Georgia and the South Sandwich Islands},
                'SS' => q{South Sudan},
                'ES' => q{Spain},
                'LK' => q{Sri Lanka},
                'SD' => q{Sudan},
                'SR' => q{Suriname},
                'SJ' => q{Svalbard and Jan Mayen},
                'SZ' => q{Swaziland},
                'SE' => q{Sweden},
                'CH' => q{Switzerland},
                'SY' => q{Syrian Arab Republic},
#                'TW' => q{Taiwan, Province of China},
                'TW' => q{Taiwan},
                'TJ' => q{Tajikistan},
#                'TZ' => q{Tanzania, United Republic of},
                'TZ' => q{Tanzania},
                'TH' => q{Thailand},
                'TL' => q{Timor-Leste},
                'TG' => q{Togo},
                'TK' => q{Tokelau},
                'TO' => q{Tonga},
                'TT' => q{Trinidad and Tobago},
                'TN' => q{Tunisia},
                'TR' => q{Turkey},
                'TM' => q{Turkmenistan},
                'TC' => q{Turks and Caicos Islands},
                'TV' => q{Tuvalu},
                'UG' => q{Uganda},
                'UA' => q{Ukraine},
                'AE' => q{United Arab Emirates},
                'GB' => q{United Kingdom},
#                'US' => q{United States of America},
                'US' => q{USA},
                'UM' => q{United States Minor Outlying Islands},
                'UY' => q{Uruguay},
                'UZ' => q{Uzbekistan},
                'VU' => q{Vanuatu},
#                'VE' => q{Venezuela, Bolivarian Republic of},
                'VE' => q{Venezuela},
#                'VN' => q{Viet Nam},
                'VN' => q{Vietnam},
#                'VG' => q{Virgin Islands, British},
                'VG' => q{British Virgin Islands},
#                'VI' => q{Virgin Islands, U.S.},
                'VI' => q{U.S. Virgin Islands},
                'WF' => q{Wallis and Futuna},
                'EH' => q{Western Sahara},
                'YE' => q{Yemen},
                'ZM' => q{Zambia},
                'ZW' => q{Zimbabwe}
            };

            # get & validate location_nation parameter
            my string $location_nation = q{};
            if ((exists $parameters->{location_nation}) and 
                (defined $parameters->{location_nation}) and
                ($parameters->{location_nation}) ne q{}) {
                $location_nation = $parameters->{location_nation};
                print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), have parameter $location_nation = ', $location_nation, "\n";
                if (not exists $nation_codes->{$location_nation}) {
                    $c->flash->{ error_msg } = 'Location nations must appear in drop-down select list.';
                    return;
                }
                $location_nation = $nation_codes->{$location_nation};
            }

            # require first name & last name & location_city & location_state & location_nation parameters
            if (($first_name eq q{}) or ($last_name eq q{}) or ($location_city eq q{}) or ($location_state eq q{}) or ($location_nation eq q{})) {
                $c->flash->{ error_msg } = 'Name and location are all required fields.';
                return;
            }

            my string $location = $location_city . ', ' . $location_state . ', ' . $location_nation;

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
                my string $shiny_user_profile_pics_dir = $ShinyCMS::ROOT_DIR . '/root/static/cms-uploads/user-profile-pics/' . $shiny_username . '/';

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
            my string $shiny_user_jobs_dir = $ShinyCMS::ROOT_DIR . 'root/user_jobs/' . $shiny_username . '/';
            #my string $learning_rperl_dir = $ShinyCMS::GITHUB_REPOS_DIR . 'rperl-latest/lib/RPerl/Learning/';
            my string $learning_rperl_dir = $ShinyCMS::LEARNING_RPERL_DIR;

            $command = 'mkdir -p ' . $shiny_user_files_dir . ' ' . $shiny_user_jobs_dir;
            print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), about to run $command = ', $command, "\n";
            $command_retval = `$command 2>&1;`;
            print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), have $CHILD_ERROR = ', $CHILD_ERROR, ', $command_retval = ', $command_retval, "\n";
            if ($CHILD_ERROR) { $c->stash->{auth0_sign_in}->{output} = 'ERROR: Failed to create user directories; ' . $command_retval; return; }

            $command = 'cp -a ' . $learning_rperl_dir . ' ' . $shiny_user_files_dir . 'LearningRPerl';
            print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), about to run $command = ', $command, "\n";
            $command_retval = `$command 2>&1;`;
            print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), have $CHILD_ERROR = ', $CHILD_ERROR, ', $command_retval = ', $command_retval, "\n";
            if ($CHILD_ERROR) { $c->stash->{auth0_sign_in}->{output} = 'ERROR: Failed to copy Learning RPerl source code files; ' . $command_retval; return; }

            # NEED FIX, CORRELATION #cff04: Debian vs Docker; do NOT run chown & chmod commands in Docker
            if ((defined $ShinyCMS::WWW_USER) and (defined $ShinyCMS::WWW_GROUP)) {
                $command = 'chown -R ' . $ShinyCMS::WWW_USER . '.' . $ShinyCMS::WWW_GROUP . ' ' . $shiny_user_files_dir . ' ' . $shiny_user_jobs_dir;
                print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), about to run $command = ', $command, "\n";
                $command_retval = `$command 2>&1;`;
                print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), have $CHILD_ERROR = ', $CHILD_ERROR, ', $command_retval = ', $command_retval, "\n";
                if ($CHILD_ERROR) { $c->stash->{auth0_sign_in}->{output} = 'ERROR: Failed to set ownership of user directories; ' . $command_retval; return; }

                $command = 'chmod -R g+rwX ' . $shiny_user_files_dir . ' ' . $shiny_user_jobs_dir;
                print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), about to run $command = ', $command, "\n";
                $command_retval = `$command 2>&1;`;
                print {*STDERR} '<<< DEBUG >>>: in Auth0::users_sign_in_auth0(), have $CHILD_ERROR = ', $CHILD_ERROR, ', $command_retval = ', $command_retval, "\n";
                if ($CHILD_ERROR) { $c->stash->{auth0_sign_in}->{output} = 'ERROR: Failed to set permissions of user directories; ' . $command_retval; return; }
            }

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

