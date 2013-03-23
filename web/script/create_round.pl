#!/usr/bin/perl 

# Created: 西元2011年03月01日 13時36分22秒
# Last Edit: 2013 Mar 23, 10:30:27 PM
# $Id$

=head1 NAME

create_round.pl - Generate a round.yaml file representing a CompComp round

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

use strict;
use warnings;

=head1 SYNOPSIS

create_round.pl -l FLA0030 -r 2 > ~drbean/class/FLA0030/comp/2/round.yaml

=cut

use strict;
use warnings;
use IO::All;
use YAML qw/LoadFile DumpFile Dump Bless/;
use List::Util qw/sum/;
use Cwd; use File::Basename;
use Grades;

=head1 DESCRIPTION

Data from swiss database and from compcomp exercise content files are collated to create a list of members, and their tables and exercises etc, which can be munged, depending on the actual tables played, and the database updated with round_table.pl.

=cut

# use lib '../../swiss/web/lib';
use lib '/var/www/cgi-bin/swiss/lib';
use Swiss;
use Swiss::Model::DB;
use Swiss::Schema;

my $script = Grades::Script->new_with_options;
my $id = $script->league || basename( getcwd );
my $round = $script->round;
my $topic = $script->exercise;
my $form = 0;

my $leagues = '/home/drbean/012';
( my $leagueid = $id ) =~ s/^([[:alpha:]]+[[:digit:]]+).*$/$1/;

my $league = League->new( leagues => $leagues, id => $leagueid );
my $g = Compcomp->new( league => $league );
my $members = $league->members;
my %members = map { $_->{id} => $_ } @$members;
my @roles = qw/White Black/;

my $connect_info = Swiss::Model::DB->config->{connect_info};
my $d = Swiss::Schema->connect( @$connect_info );

my $foundround = $d->resultset('Round')->find( { tournament => $id } )
                ->value;
my $m = $d->resultset('Matches')->search({ tournament => $id,
		round => $round });

my (%round, $players);
my $n = 0;
while ( my $match = $m->find({ pair => $n }) )  {
	my $pair = { White => $match->white, Black => $match->black };
	if ( $pair->{Black} eq 'Bye' ) {
	    $round{bye} = $pair->{White};
	    $n++;
	}
	else {
	    Bless( $pair )->keys( [ qw/White Black/ ] );
	    $players->{ $n++ } = $pair;
	}
}

my @tables = sort {$a<=>$b} keys %$players;
Bless( $players )->keys([ @tables ]); 

$round{group} = $players;
$round{round} = $round;
$round{late} = [undef];
$round{assistant} = undef;
$round{divisions} = undef;
$round{dispensation} = undef;
$round{week} = undef;
$round{pairing} = "swiss";
$round{payprotocol} = "meritPay";
$round{text} = undef;
$round{activity}->{$topic}->{$form} = \@tables;

print Dump \%round;

=head1 AUTHOR

Dr Bean C<< <drbean at cpan, then a dot, (.), and org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2011 Dr Bean, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

# End of create_round.pl

# vim: set ts=8 sts=4 sw=4 noet:
