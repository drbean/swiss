package Swiss::Controller::Pairing;

# Last Edit: 2009 10月 14, 11時50分56秒
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
	my $tourid = $c->session->{tournament};
	my $round = $c->session->{"${tourid}_round"} + 1;
	my $members = $c->model('DB::Members')->search(
		{ tournament => $tourid });
	my $rounds = $c->stash->{rounds};
	my (@playerlist, @absentees);
	while ( my $member = $members->next ) {
		my $player = {
			map { $_ => $member->profile->$_ }
				$members->result_source->columns };
		#my $player = $member->profile->$_;
		push @playerlist, $player;
		push @absentees, $player if $player->{absent};
	}
$DB::single=1;
	my $tourney = $c->forward( 'setupTournament', {
			name => $tourid,
			round => $round,
			rounds => $rounds,
			entrants => \@playerlist,
			absentees => \@absentees,
		} );
	my ($games, $latestscores, %pairingtable);
	for my $field ( qw/pairingnumber opponent role float score/ ) {
		$members->reset;
		while ( my $member = $members->next ) {
			$pairingtable{$field}->{$member->id} =
				$member->$field->get_column($field)->all;
		}
	}
	if ( $c->request->params->{pairingtable} ) {
		my $table = $c->request->params->{pairingtable};
		%pairingtable = $c->model('GTS')->parseTable($tourney, $table);
		$latestscores = $pairingtable{score};
	}
	elsif ( $c->request->args->[0] eq 'editable' ) {
		@playerlist = buildPairingtable( $c, $tourid, \@playerlist,
			\%pairingtable );
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
				$tourney, \%pairingtable, $params);
			$pairingtable{score} = $latestscores;
			for my $player ( @{ $tourney->entrants } ) {
				my $id = $player->id;
				$player->score( $latestscores->{$id} );
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
			$tourney, \%pairingtable, $round );
		$c->stash->{round} = $round;
		$c->stash->{roles} = $c->model('GTS')->roles;
		$c->stash->{games} = $games;
		$c->stash->{error_msg} = "Can't pair Round " . ($round+1) .
			" with unfinished games in Round $round.";
		$c->stash->{template} = "cards.tt2";
		return;
	}
	my $newhistory = ( $games and ref $games eq 'ARRAY' ) ?
		$c->model('GTS')->changeHistory($tourney, \%pairingtable,
				$games) : \%pairingtable;
	my %cookhist = $c->model('GTS')->historyCookies($tourney, $newhistory);
	setCookie( $c, %cookhist );
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
	my $round = $c->session->{"${tourid}_round"} + 1;
	my $tournament = $c->model('DB::Tournaments')->find(
		{ id => $tourid });
	my $members = $tournament->members;
	my @columns = Swiss::Schema::Result::Players->columns;
	my $rounds = $tournament->rounds;
	my (@playerlist, @absentees);
	while ( my $member = $members->next ) {
		my $player = { map { $_ => $member->profile->$_ } @columns };
	#for my $member ( @members ) {
	#	my $player = $member->profile;
		push @playerlist, $player;
		push @absentees, $player if $player->{absent};
	}
my $args = {
			name => $tourid,
			round => $round,
			rounds => $rounds,
			entrants => \@playerlist,
			absentees => \@absentees,
		};
#for my $group ( qw/entrants absentees/ ) {
#	my $players = $args->{$group};
#	my @band = map {Games::Tournament::Contestant::Swiss->new(%$_)}
#			@$players;
#	$args->{$group} = \@band;
#}
#my $tourney = Games::Tournament::Swiss->new( %$args );
#$tourney->assignPairingNumbers;
#my $numberset = $c->model('DB::Pairingnumbers')->search( {
#		tournament => $tourid } );
#my $entrants = $tourney->entrants;
#for my $entrant ( @$entrants ) {
#	$numberset->update_or_create( { tournament => $tourid, 
#	player => $entrant->id,
#	pairingnumber => $entrant->pairingNumber } );
#}
$DB::single=1;
	my $tourney = $c->model( 'SetupTournament', {
			name => $tourid,
			round => $round,
			rounds => $rounds,
			entrants => \@playerlist,
			absentees => \@absentees,
		} );
	my ($latestscores, $pairingtable);
	for my $field ( qw/pairingnumber opponent role float score/ ) {
		$members->reset;
		my $fieldhistory;
		while ( my $member = $members->next ) {
			my $player = $member->profile;
			my $values = $member->$field->get_column($field);
			if ( blessed( $values ) and $values->isa(
					'DBIx::Class::ResultSetColumn') ) {
				my @all =$values->all;
				$fieldhistory->{$member->profile->id} = \@all;
			}
			else {
				$fieldhistory->{$member->profile->id}=$values;
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
	my %cookhist = $c->model('GTS')->historyCookies($tourney, $newhistory);
	setCookie( $c, %cookhist );
	$round = $tourney->round;
	setCookie( $c, "${tourid}_round" => $round );
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


=head2 setupTournament

Passing round a tournament, with players, is easier.

=cut

sub setupTournament {
	my ($self, $c, $args) = @_;
	for my $group ( qw/entrants absentees/ ) {
		my $players = $args->{$group};
		my @band = map {Games::Tournament::Contestant::Swiss->new(%$_)}
				@$players;
		$args->{$group} = \@band;
	}
	my $tournament = Games::Tournament::Swiss->new( %$args );
	$tournament->assignPairingNumbers;
	my $tourid = $c->session->{tournament};
	my $numberset = $c->model('DB::Pairingnumbers')->search( {
			tournament => $tourid } );
	my $entrants = $tournament->entrants;
	for my $entrant ( @$entrants ) {
		$numberset->update_or_create( { tournament => $tourid, 
		player => $entrant->id,
		pairingnumber => $entrant->pairingnumber } );
	}
	return $tournament;
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