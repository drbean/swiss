#!/usr/bin/perl

=head1 NAME

updateplayers.pl - Change players in database via script

=head1 SYNOPSIS

updateplayers.pl -l FLA0031 -r 2

=head1 DESCRIPTION

"Update missing players, eg transfers or without English names, not in original populate of Players, but now in league.yaml." Update ratings for players from the given round. Also, update Members. Members who are no longer 'active' in league.yaml are 'Absent'. Returning members are now not absent. TODO What round is it?


=head1 AUTHOR

Dr Bean

=head1 COPYRIGHT


This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/../lib";
use Cwd; use File::Basename;

use List::MoreUtils qw/none/;
use IO::All;
my $io = io '-';

use Grades;

use YAML qw/LoadFile/;

my $script = Grades::Script->new_with_options;
my $tournament = $script->league || basename( getcwd );
( my $leagueid = $tournament ) =~ s/^([[:alpha:]]+[[:digit:]]+).*$/$1/;
my $round = $script->round;

my $config = LoadFile "/var/www/cgi-bin/swiss/swiss.yaml";
my $name = $config->{name};
require $name . ".pm";
my $model = "${name}::Schema";
my $modelfile = "$name/Model/DB.pm";
my $modelmodule = "${name}::Model::DB";
# require $modelfile;

my $connect_info = $modelmodule->config->{connect_info};
my $d = $model->connect( @$connect_info );
my $players = $d->resultset('Players');
my $ratings = $d->resultset('Ratings')->search({ tournament => $tournament });
my $members = $d->resultset('Members')->search({ tournament => $tournament });
my (%players, @newbies, @absentees, @returnees, @ratings);
my $league = League->new( leagues => $config->{leagues}, id => $leagueid );
my $filemembers = $league->members;
my $activemembers = $filemembers;
my $dropouts = $league->yaml->{out};
foreach my $member ( @$filemembers ) {
	my $id = $member->{id};
	my $dbmember = $members->find({ player => $id,
			tournament => $tournament });
	$players{$id} = {
		name => $member->{name},
		id => $member->{id},
		};
	unless ( $dbmember ) {
		push @newbies, {
			tournament => $tournament, player => $id,
			absent => 'False', firstround => $round };
		push @ratings, { 
				player => $member->{id},
				tournament => $tournament,
				round => ($round - 1),
				value => $member->{rating} || 0 };
	}
}
$members->reset;
while ( my $dbmember = $members->next ) {
	my $id = $dbmember->player;
	my $firstround = $dbmember->firstround || 1;
	if ( none { $_ eq $id } map { $_->{id} } @$activemembers ) {
		push @absentees, {
			tournament => $tournament, player => $id,
			absent => 'True', firstround => $firstround };
	}
	elsif ( $dbmember->absent eq 'True' ) {
		push @returnees, { 
			tournament => $tournament, player => $id,
			absent => 'False', firstround => $firstround };
	}
}
my @players = values %players;
$players->update_or_create( $_ ) for @players;
$members->update_or_create( $_ ) for @absentees;
$members->update_or_create( $_ ) for @newbies;
$members->update_or_create( $_ ) for @returnees;
$ratings->update_or_create( $_ ) for @ratings;

my $n=0;
if ( @absentees ) {
	my $pool = [ @$filemembers, @$dropouts ];
	my %pool = map { $_->{id} => $_ } @$pool;
	my %out = map { $_->{id} => $_ } @$dropouts;
	@pool{ keys %out } = values %out;
	print "Absent players and dropouts:\n", map
		{ $n++ . " $pool{$_->{player}}->{name}\t$_->{player}\n" } @absentees;
}
$n=0;
print "New players:\n", map { $n++ . " $players{$_->{player}}->{name}\t$_->{player}\n"} @newbies;
$n=0;
print "Returning players:\n", map	{ $n++ .
			" $players{$_->{player}}->{name}\t$_->{player}\n"
									} @returnees;
