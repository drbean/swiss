#!/usr/bin/perl

=head1 NAME

updateratings.pl - Enter new ratings of players in database via script

=head1 SYNOPSIS

updateratings.pl -l FLA0018

=head1 DESCRIPTION

This script is run after play is finished in one round and before the next round is paired and played.

The rating of round n is the rating after play in that round, and is the rating that applies to the game in round n+1.

It is calculated from the ratings in round n-1 of the player and the opponent on the basis of play in round n.

The round n is found from the conversations of the league that is participating in the tournament, using Grades.pm.

Ratings in round 0 are in league.yaml. The ratings of missing players, eg transfers, not in the original populate of Players, but now in league.yaml, for round 0 before rating changes are also updated.

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
use lib "web/lib";

use IO::All;
my $io = io '-';
use YAML qw/Dump/;

use Grades;
use Games::Ratings::Chess::FIDE;

use Config::General;
use List::Util qw/first/;
use List::MoreUtils qw/all/;
use Scalar::Util qw/looks_like_number/;

sub run {
	my $script = Grades::Script->new_with_options;
	my $tournament = $script->league or die "League id?";

	my %config = Config::General->new( "/var/www/cgi-bin/swiss/swiss.conf" )->getall;
	my $name = $config{name};
	require $name . ".pm";
	my $model = "${name}::Schema";
	my $modelfile = "$name/Model/DB.pm";
	my $modelmodule = "${name}::Model::DB";
	my $connect_info = $modelmodule->config->{connect_info};
	my $d = $model->connect( @$connect_info );

	my $league = League->new( leagues =>
		$config{leagues}, id => $tournament );
	my $comp = Compcomp->new({ league => $league });
	my $thisweek = $league->approach eq 'Compcomp'?
			$comp->all_events->[-1]: 0;
	my $thisround = $script->round || $thisweek || 0;
	my $lastround = $thisround - 1;
	my $tourney = $d->resultset('Tournaments')->find({ id => $tournament });
	my $matches = $tourney->matches->search({ round => $thisround });
	my %ratings;
	my $entrants = $league->members;
	my %entrants = map { $_->{id} => $_ } @$entrants;
	my $members = $tourney->members;
	my %unpaired = %entrants;
	my @bothratings;

	my $set_old_rating = sub {
		my $id = shift;
		my $member = $members->find({
			tournament => $tournament, player => $id });
		my ( $oldRating );
		$oldRating = $member->rating->find({
				tournament => $tournament,
				round => $lastround });
		unless ( $oldRating ) {
			$oldRating = $entrants{$id}->{rating} || 0;
			$ratings{$id} = { 
					player => $id,
					tournament => $tournament,
					round => $thisround,
					value => $oldRating };
			warn " Player $id had no rating in round " .
				$lastround . ", assigning $oldRating,";
		}
		else {
			my $oldValue = $oldRating->value;
			warn "Player $id had no, or zero rating in round " .
				$lastround unless $oldValue;
			push @bothratings, $oldValue;
			$ratings{$id} = { 
					player => $id,
					tournament => $tournament,
					round => $thisround,
					value => $oldValue };
			warn "$oldValue rating for Player $id, in previous Round $lastround?"
				unless ( looks_like_number $oldValue );
		}
	};

	while ( my $match = $matches->next ) {
		my $table = $match->pair;
		my %ids = map { ucfirst($_) => $match->$_ } qw/white black/;
		my $win = $match->win;
		my $forfeit = $match->forfeit;
		my $tardy = $match->tardy;
		PLAYER: for my $role ( keys %ids ) {
			my $id = $ids{$role};
			next PLAYER if $id eq 'Bye';
			delete $unpaired{$id};
			$set_old_rating->($id);
		}
		unless ( @bothratings and all { looks_like_number $_ } @bothratings or
			$ids{Black} eq 'Bye' )
		{
			warn
	"Rating for Table $table player, $ids{White}, or partner in Round " .
				$thisround . "?";
		}
		elsif (  $ids{Black} ne 'Bye' and $win ne 'None' and $win ne 'Unknown' and ( $forfeit eq 'None' or $forfeit eq 'Unknown' ) and ( $tardy eq 'None' or $tardy eq 'Unknown' ) ) {
			my $rater = Games::Ratings::Chess::FIDE->new;
			for my $role ( keys %ids ) {
				my $id = $ids{$role};
				my $opprole = first { $_ ne $role } keys %ids;
				my $oppid = $ids{$opprole};
				my $result = $win eq $role? 'win':
					$win eq $opprole? 'loss':
					$win eq 'Both'? 'draw': 'None of above';
				$rater->set_rating( $ratings{$id}->{value} );
				$rater->set_coefficient( 25 );
				$rater->add_game( { opponent_rating =>
						$ratings{$oppid}->{value},
						result => $result } );
				$ratings{$id}->{value} = $rater->get_new_rating;
			}
		}
		undef @bothratings;
	}

	NONPLAYER: for my $id ( keys %unpaired ) {
		$set_old_rating->($id);
	}
	$members->reset;
	while ( my $member = $members->next ) {
		my $id = $member->player;
		$set_old_rating->($id);
	}
	my $ratings = $d->resultset('Ratings');
	$ratings->update_or_create( $_ ) for values %ratings;
	print Dump { map { $_ => $ratings{$_}->{value} } keys %ratings };

}

run() unless caller;

1;
