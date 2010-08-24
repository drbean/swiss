package Swiss::Controller::Pairing;

# Last Edit: 2010 Aug 24, 03:21:26 PM
# $Id$

use strict;
use warnings;
use parent 'Catalyst::Controller';

use List::MoreUtils qw/none any all notall/;
use Scalar::Util qw/blessed/;
use Games::Tournament::Contestant::Swiss;
use Games::Tournament::Swiss;


=head1 NAME

Swiss::Controller::Root - Root Controller for Swiss

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS


=head2 pairingtable

Offer pairing table for later rounds 

=cut

sub pairingtable : Local {
        my ($self, $c) = @_;
	my $cookies = $c->request->cookies;
	my $tourname = $c->request->cookie('tournament')->value;
	my @playerlist = $c->model('GTS')->turnIntoPlayers($tourname, $cookies);
	my $round = ( $c->request->cookie("${tourname}_round") and
		$c->request->cookie("${tourname}_round")->isa(
			'CGI::Simple::Cookie') ) ?
		$c->request->cookie("${tourname}_round")->value + 1: 1;
	my %histories = $c->model('GTS')->readHistory(
				$tourname, \@playerlist, $cookies, $round);
	my @pairingtable = buildPairingtable($c, $tourname,
		\@playerlist, \%histories );
	$c->stash->{tournament} = $tourname;
	$c->stash->{round} = $round;
	$c->stash->{playerlist} = \@pairingtable;
	$c->stash->{template} = "pairtable.tt2";
}

=head2 buildPairingtable

Common code in pairingtable, final_players, nextround actions that converts player list, pairing numbers, opponents, roles, and floats histories and scores and creates an array of hashes with player histories for each individual player, suitable for display as a pairing table. Extracted into a function.

=cut

sub buildPairingtable {
	my ($c, $tourname, $playerlist, $histories) = @_; 
	for my $player ( @$playerlist ) {
		my $id = $player->{id};
		for my $type ( qw/pairingnumber opponent role float score/ ) {
			my $run = $histories->{$type}->{$id};
			$player->{$type} = $run;
		}
	}
	return @$playerlist;
}


=head2 preppair

Prepare to pair next round

=cut

sub preppair : Local {
        my ($self, $c) = @_;
	my $requestargs = $c->request->args;
	my $tourid = $c->session->{tournament};
	my $round = $c->model('DB::Round')->find( { tournament => $tourid } )
			->round;
	my $members = $c->model('DB::Members')->search(
		{ tournament => $tourid });
	my @columns = Swiss::Schema::Result::Players->columns;
	my $rounds = $c->stash->{rounds};
	my (@playerlist, @absentees);
	while ( my $member = $members->next ) {
		my $player = { map { $_ => $member->profile->$_ } @columns };
		push @playerlist, $player;
		push @absentees, $player if $member->absent eq 'True';
	}
	my $tourney = $c->model( 'SetupTournament', {
			name => $tourid,
			round => $round,
			rounds => $rounds,
			entrants => \@playerlist,
			absentees => \@absentees,
		} );
	my ($games, $latestscores, $pairingtable);
	for my $field ( qw/pairingnumber score firstround/ ) {
		$members->reset;
		my $fieldhistory;
		while ( my $member = $members->next ) {
			my $player = $member->profile;
			my $value = $member->$field->$field;
			$fieldhistory->{$member->profile->id}=$value;
		}
		$pairingtable->{$field} = $fieldhistory;
	}
	for my $field ( qw/opponent role float/ ) {
		$members->reset;
		my $fieldhistory;
		while ( my $member = $members->next ) {
			my $player = $member->profile;
			my $id = $player->id;
			my $values = $member->$field;
			while ( my $pair = $values->next ) {
				my $round = $pair->round;
				my $value = $pair->$field;
				$fieldhistory->{$id}->[$round - 1] = $value;
			}
		}
		$pairingtable->{$field} = $fieldhistory;
	}
	if ( $c->request->params->{pairingtable} ) {
		my $table = $c->request->params->{pairingtable};
		$pairingtable = $c->model('GTS')->parseTable($tourney, $table);
		$latestscores = $pairingtable->{score};
	}
	elsif ( $requestargs and $requestargs->[0] eq 'editable' ) {
		@playerlist = buildPairingtable( $c, $tourid, \@playerlist,
			$pairingtable );
		$c->stash->{pairtable} = \@playerlist;
		$c->stash->{tournament} = $tourid;
		$c->stash->{round} = ++$round;
		$c->stash->{roles} = $c->model('GTS')->roles;
		$c->stash->{template} = 'paireditable.tt2';
		return;
	}
	else {
		if ( exists $c->request->params->{Submit} and
			$c->request->params->{Submit} eq
				"Record Round $round results" ) {
			my $params = $c->request->params;
			$latestscores = $c->model('GTS')->assignScores(
				$tourney, $pairingtable, $params);
			$pairingtable->{score} = $latestscores;
			my $scoreset = $c->model('DB::Scores');
			for my $player ( @{ $tourney->entrants } ) {
				next if $player->absent;
				my $id = $player->id;
				$player->score( $latestscores->{$id} );
				$scoreset->update_or_create( {
					tournament => $tourid, player => $id,
					score => $latestscores->{$id} } );
			}
			my $scorestring;
			$scorestring = join '&', map { $latestscores->{$_} }
				map { $_->{id} } @playerlist if
				all { defined } values %$latestscores;
		}
	}
	if ( ( not defined $latestscores or not all { defined }
				values %$latestscores ) and $round >= 2 ) {
		$games = $c->model('GTS')->postPlayPaperwork(
			$tourney, $pairingtable, $round );
		$c->stash->{round} = $round;
		$c->stash->{roles} = $c->model('GTS')->roles;
		$c->stash->{games} = $games;
		$c->stash->{error_msg} = "Can't pair Round " . ($round+1) .
			" with unfinished games in Round $round.";
		$c->stash->{template} = "cards.tt2";
		return;
	}
	my $newhistory = ( $games and ref $games eq 'ARRAY' ) ?
		$c->model('GTS')->changeHistory($tourney, $pairingtable,
				$games) : $pairingtable;
	for my $field ( qw/pairingnumber / ) {
		my $Fields = ucfirst $field . 's';
		my $fieldset = $c->model( "DB::$Fields" );
		$members->reset;
		while ( my $member = $members->next ) {
			my $id = $member->profile->id;
			my $fieldhistory = $newhistory->{$field}->{$id};
			$fieldset->update_or_create( {
				tournament => $tourid,
				player => $id, 
				$field => $fieldhistory
			} );
		}
	}
	for my $field ( qw/opponent role float/ ) {
		my $Fields = ucfirst $field . 's';
		my $fieldset = $c->model( "DB::$Fields" );
		$members->reset;
		while ( my $member = $members->next ) {
			my $id = $member->profile->id;
			my $fieldhistory = $newhistory->{$field}->{$id};
			my %series = map { ($_+1) => $fieldhistory->[$_] }
					0 .. $#$fieldhistory;
			for my $round ( keys %series ) {
				$fieldset->update_or_create( {
					tournament => $tourid,
					player => $id, 
					round => $round,
					$field => $series{$round}
				} );
			}
		}
	}
	@playerlist = buildPairingtable( $c, $tourid, \@playerlist,
		$newhistory );
	$c->stash->{pairtable} = \@playerlist;
	$c->stash->{tournament} = $tourid;
	$c->stash->{round} = ++$round;
	$c->stash->{roles} = $c->model('GTS')->roles;
	$c->stash->{games} = $games;
	$c->stash->{template} = "preppair.tt2";
}


=head2 nextround

Pair first round

=cut

sub nextround : Local {
        my ($self, $c) = @_;
	my $tourid = $c->session->{tournament};
	my $round = $c->model('DB::Round')->find( { tournament => $tourid } )
			->round;
	$round++;
	my $tournament = $c->model('DB::Tournaments')->find(
		{ id => $tourid });
	my $members = $tournament->members;
	my @columns = Swiss::Schema::Result::Players->columns;
	my $rounds = $tournament->rounds;
	my (@playerlist, @absentees);
	while ( my $member = $members->next ) {
		my $player = { map { $_ => $member->profile->$_ } @columns };
		$player->{firstround} = $member->firstround;
		my $rating = $member->profile->rating->find({
				tournament => $tourid, round => $round-1 });
		$player->{rating} = $rating->value;
		push @playerlist, $player;
		push @absentees, $player if $member->absent eq 'True';
	}
	my $tourney = $c->model( 'SetupTournament', {
			name => $tourid,
			round => ( $round - 1 ),
			rounds => $rounds,
			entrants => \@playerlist,
			absentees => \@absentees,
		} );
	my ($latestscores, $pairingtable);
	for my $field ( qw/score/ ) {
		$members->reset;
		my $fieldhistory;
		while ( my $member = $members->next ) {
			my $player = $member->profile;
			my $row = $member->$field;
			my $value = $row? $row->$field: 0;
			$fieldhistory->{$player->id} = $value;
		}
		$pairingtable->{$field} = $fieldhistory;
	}
	for my $field ( qw/opponent role float/ ) {
		$members->reset;
		my $fieldhistory;
		while ( my $member = $members->next ) {
			my $player = $member->profile;
			my $id = $player->id;
			my $values = $member->$field;
			while ( my $pair = $values->next ) {
				my $round = $pair->round;
				my $value = $pair->$field;
				$fieldhistory->{$id}->[$round - 1] = $value;
			}
		}
		$pairingtable->{$field} = $fieldhistory;
	}
	for my $n ( 0 .. $#playerlist ) {
		my $id = $playerlist[$n]->{id};
		$tourney->entrants->[$n]->pairingNumber(
		$pairingtable->{pairingnumber}->{$id} );
	}
	my ($mess, $log, $games) = $c->model('GTS')->pair( {
			tournament => $tourney,
			history => $pairingtable } );
	if ( $mess and $mess =~ m/^All joined into one .*, but no pairings!/ or
		@$games * 2 < @playerlist - @absentees ) {
		$c->stash->{error_msg} = $mess;
		$c->stash->{round} = $round - 1;
		$c->stash->{template}  = "gameover.tt2";
		return;
	}
	$tourney->round($round);
	my $newhistory = $c->model('GTS')->changeHistory(
			$tourney, $pairingtable, $games );
	my $n = 0;
	my $cardset = $c->model( "DB::Cards" );
	for my $game ( @$games ) {
		my $card = $c->model('GTS')->cardData( $game );
		$cardset->update_or_create( {
			tournament => $tourid,
			round => $round,
			pair => $n++, 
			white => $card->{white},
			black => $card->{black},
			float => $card->{float}
				} );
	}
	$round = $tourney->round;
	$c->session->{"${tourid}_round"} = $round;
	$c->model('DB::Round')->find({ tournament => $tourid })->update({
			round=>$round });
	if ( $c->request->params->{pairtable} ) {
		@playerlist = buildPairingtable( $c, $tourid, \@playerlist, 
			$newhistory );
		$c->stash->{pairtable} = \@playerlist;
	}
	$c->stash->{tournament} = $tourid;
	$c->stash->{round} = $round;
	$c->stash->{roles} = $c->model('GTS')->roles;
	$c->stash->{games} = $games;
	$c->stash->{log} = $log if $c->request->params->{log};
	$c->stash->{template} = "draw.tt2";
}


=head2 end

Attempt to render a view, if needed.

=cut

sub end : ActionClass('RenderView') {}

=head1 AUTHOR

Catalyst developer

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
