#!/usr/bin/perl

=head1 NAME

updategrades.pl - Enter new grades of players in database via script

=head1 SYNOPSIS

updategrades.pl -l FLA0018

=head1 DESCRIPTION

This script is run after play is finished in one round and before the next round is paired and played.

The grade of round n is the grade after play in that round, and is the rating that applies to the game in round n+1.

It is the grade that the player is expected to get in the course.

The round n is found from the conversations of the league that is participating in the tournament, using Grades.pm.

Grades in round 0 are 80. TODO The grades of missing players, eg transfers, not in the original populate of Players, but now in league.yaml, for round 0 before rating changes?

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

use IO::All;
my $io = io '-';
use YAML qw/Dump/;

use Grades;

use Config::General;
use List::Util qw/first/;
use List::MoreUtils qw/all/;
use Scalar::Util qw/looks_like_number/;

sub run {
	my $script = Grades::Script->new_with_options;
	my $tournament = $script->league or die "League id?";

	my %config = Config::General->new( "$Bin/../swiss.conf" )->getall;
	my $name = $config{name};
	require $name . ".pm";
	my $model = "${name}::Schema";
	my $modelfile = "$name/Model/DB.pm";
	my $modelmodule = "${name}::Model::DB";
	my $connect_info = $modelmodule->config->{connect_info};
	my $d = $model->connect( @$connect_info );

	my $league = League->new( leagues =>
		$config{leagues}, id => $tournament );
	my $grades = Grades->new({ league => $league });
	my $thisweek = $league->approach eq 'Compcomp'?
			$grades->classwork->all_weeks->[-1]: 0;
	my $thisround = $script->round || $thisweek || 0;
	my $lastround = $thisround - 1;
	my $tourney = $d->resultset('Tournaments')->find({ id => $tournament });
	my %ratings;
	my $entrants = $league->members;
	my %entrants = map { $_->{id} => $_ } @$entrants;
	my $members = $tourney->members;
	my $grade = $grades->grades;
	my $ratings = $d->resultset('Ratings');
	while ( my $member = $members->next ) {
		my $id = $member->player;
		my $grade = $grade->{$id} || $ratings->find({ tournament => $tournament,
				player => $id, round => ($thisround - 1) })->value || 0;
		$ratings{$id} = { 
				player => $id,
				tournament => $tournament,
				round => $thisround,
				value => $grade };
	}
	$ratings->update_or_create( $_ ) for values %ratings;
	print Dump { map { $_ => $ratings{$_}->{value} } keys %ratings };

}

run() unless caller;

1;
