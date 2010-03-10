#!/usr/bin/perl

=head1 NAME

updateratings.pl - Enter new ratings of players in database via script

=head1 SYNOPSIS

updateratings.pl

=head1 DESCRIPTION

"Update ratings for missing players, eg transfers, not in original populate of Players, but now in league.yaml, for round 0 before rating changes."

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

use Grades;
use Games::Ratings::Chess::FIDE;

use Config::General;

my $script = Grades::Script->new_with_options;
my $tournament = $script->league;
my $round = $script->round - 1;

my @MyAppConf = glob( "$Bin/../*.conf" );
die "Which of @MyAppConf is the configuration file?"
			unless @MyAppConf == 1;
my %config = Config::General->new($MyAppConf[0])->getall;
my $name = $config{name};
require $name . ".pm";
my $model = "${name}::Schema";
my $modelfile = "$name/Model/DB.pm";
my $modelmodule = "${name}::Model::DB";
# require $modelfile;

my $connect_info = $modelmodule->config->{connect_info};
my $d = $model->connect( @$connect_info );
my $members = $d->resultset('Members')->search({ tournament => $tournament });

my @ratings;
my $league = League->new( leagues =>
	$config{leagues}, id => $tournament );
my $grades = Grades->new( league => $league );
my $entrants = $league->members;
my %entrants = map { $_->{id} => $_ } @$entrants;
my $points = $grades->points( "comp/$round" );
my %seen;
while ( my $member = $members->next ) {
	my $id = $member->player;
	my $oldRating;
	$oldRating = $member->rating->find({
			tournament => $tournament,
			round => ($round - 1) });
	unless ( $oldRating ) {
	$oldRating = $entrants{$id}->{rating};
		next;
	}
	$oldRating = $oldRating->value;
	warn "Player $id had no rating in round $round" unless $oldRating;
	my $newRating;
	my $opponent = $member->opponent->find({
			tournament => $tournament,
			round => $round });
	my $point = $points->{$id};
	unless ( $opponent and $opponent->opponent ne 'Unpaired'
			and $opponent->opponent ne 'Bye' ) {
		warn
			"Player $id got $point points in Round $round, but $opponent is " .
					$opponent->opponent . "?" if $point;
		$newRating = $oldRating;
	}
	else {
		#my $Orating = $opponent->profile->rating->find({
		#		tournament => $tournament,
		#		round => ($round - 1) })->value;
		my $Orating = $d->resultset('Ratings')->find({ 
				player => $opponent->opponent,
				tournament => $tournament,
				round => ($round - 1) })->value;
		my $result = $point == 5? "win": $point == 3? "loss": "draw";
		my $rater = Games::Ratings::Chess::FIDE->new;
		$rater->set_rating( $oldRating );
		$rater->set_coefficient( 25 );
		$rater->add_game( { opponent_rating => $Orating,
				result => $result } );
		$newRating = $rater->get_new_rating;
	}
	push @ratings, { 
			player => $id,
			tournament => $tournament,
			round => $round,
			value => $newRating || $entrants{$id}->{rating} || 0 };
}
my $ratings = $d->resultset('Ratings');
$ratings->update_or_create( $_ ) for @ratings;
