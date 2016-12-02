package Plack::App::Apache2FileManager::Mocks;

BEGIN {
    for (
        qw/Log Util Const Request RequestIO RequestRec RequestUtil ServerUtil Upload/
        )
    {
        $INC{ 'Apache2/' . $_ . '.pm' } = '1';
    }
}

package Apache2::Const {
    use constant {
        DECLINED => -1,
        OK       => 200,
    };
}

package Apache2::Request;
sub new { }

package Apache2::Util;



# WBRASWELL
use Data::Dumper;

#sub escape_path { return "" . $_[0] }
sub escape_path { 
#    print {*STDERR} 'in Mocks::escape_path(), received @_ = ', Dumper(\@_), "\n";
    return "" . $_[0];
}




package Plack::App::Apache2FileManager::Mocks;

use Moose;

has 'document_root' => ( is => 'ro', required => 1, isa => 'Str' );
has 'request' => ( is => 'ro', required => 1, handles => [qw/param uri/] );
has 'status' => ( is => 'rw', default => 200 );
has 'response' =>
    ( is => 'ro', lazy_build => 1, handles => [qw/content_type/] );

sub pool {}

sub hostname {
    my $self = shift;
    return $self->request->base->host;
}

sub print {
    my ($self, $content) = @_;
    my $body = $self->response->body // '';
    $self->response->body( $body . $content );
    return 1;
}

sub _build_response {
    my $self = shift;
    $self->request->new_response( $self->status );
}

sub dir_config {
    my ( $self, $key ) = @_;
    return $Plack::App::Apache2FileManager::CONFIG->{$key};
}

1;
