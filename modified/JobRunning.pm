use utf8;
package ShinyCMS::Schema::Result::JobRunning;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

ShinyCMS::Schema::Result::JobRunning

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=item * L<DBIx::Class::TimeStamp>

=item * L<DBIx::Class::EncodedColumn>

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime", "TimeStamp", "EncodedColumn");

=head1 TABLE: C<job_running>

=cut

__PACKAGE__->table("job_running");

=head1 ACCESSORS

=head2 screen_pid

  data_type: 'integer'
  is_nullable: 0

=head2 shiny_uid

  data_type: 'integer'
  is_nullable: 0

=head2 screen_session

  data_type: 'text'
  is_nullable: 0

=head2 screen_logfile

  data_type: 'text'
  is_nullable: 0

=head2 compute_nodes

  data_type: 'text'
  is_nullable: 0

=head2 command

  data_type: 'text'
  is_nullable: 0

=head2 command_pid

  data_type: 'integer'
  is_nullable: 0

=head2 output_line

  data_type: 'integer'
  is_nullable: 0

=head2 output_character

  data_type: 'integer'
  is_nullable: 0

=head2 status

  data_type: 'text'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "screen_pid",
  { data_type => "integer", is_nullable => 0 },
  "shiny_uid",
  { data_type => "integer", is_nullable => 0 },
  "screen_session",
  { data_type => "text", is_nullable => 0 },
  "screen_logfile",
  { data_type => "text", is_nullable => 0 },
  "compute_nodes",
  { data_type => "text", is_nullable => 0 },
  "command",
  { data_type => "text", is_nullable => 0 },
  "command_pid",
  { data_type => "integer", is_nullable => 0 },
  "output_line",
  { data_type => "integer", is_nullable => 0 },
  "output_character",
  { data_type => "integer", is_nullable => 0 },
  "status",
  { data_type => "text", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</screen_pid>

=back

=cut

__PACKAGE__->set_primary_key("screen_pid");


# Created by DBIx::Class::Schema::Loader v0.07039 @ 2016-12-31 19:38:21
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:dez2HHAkLSf3a83YWzOmNQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
