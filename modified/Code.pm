# [[[ PREPROCESSOR ]]]
# <<< TYPE_CHECKING: OFF >>>

# [[[ HEADER ]]]
#use RPerl;
package ShinyCMS::Controller::Code;
use strict;
use warnings;
our $VERSION = 0.001_000;

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
use Data::Dumper;
#use Apache2::FileManager;

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

sub base : Chained( '/base' ) : PathPart( 'code' ) : CaptureArgs( 0 ) {
    my ( $self, $c ) = @_;
    
    # Stash the upload_dir setting
    $c->stash->{ upload_dir } = $c->config->{ upload_dir };
    
    # Stash the name of the controller
    $c->stash->{ controller } = 'Code';
}

=head2 view_editor

Display the IDE code editor.

=cut

sub view_editor : Chained( 'base' ) : PathPart( 'editor' ) {
    my ( $self, $c ) = @_;
#    print {*STDERR} '<<< DEBUG >>>: in Code::view_editor(), received $self = ', "\n", Dumper($self), "\n\n";
#    print {*STDERR} '<<< DEBUG >>>: in Code::view_editor(), received $c = ', "\n", Dumper($c), "\n\n";

    $c->stash->{ template } = 'code/view_editor.tt';

    # NEED FIX: must be running in modperl mode for Apache2::FileManager to work
    #my $obj = Apache2::FileManager->new({ DOCUMENT_ROOT => '/home/wbraswell/public_html/cloudforfree.org-latest/root/user_files/' });
    #$obj->print();
    
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

    $c->stash->{ editor } = { title => 'IDE Code Editor' };
    $c->stash->{ file_manager } = { NEED_ADD_DATA_FM => 23 };
    $c->stash->{ file_input } = { default => $learning_rperl_ch1_ex1 };
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

