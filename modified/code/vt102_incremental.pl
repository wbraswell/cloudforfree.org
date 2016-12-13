#!/usr/bin/perl
use strict;
use warnings;
use Term::VT102::Incremental;
use Data::Dumper;

my $vti = Term::VT102::Incremental->new(
  rows => 50,
  cols => 100,
);
 
$vti->process('echo HOWDY');
my $updates = $vti->get_increment(); # at time X
print {*STDERR} '<<<DEBUG>>>: $updates = ', Dumper($updates), "\n";
 
$vti->process('echo DOODY');
my $updates_since_time_X = $vti->get_increment(); # at time Y
print {*STDERR} '<<<DEBUG>>>: $updates_since_time_X = ', Dumper($updates_since_time_X), "\n";

