package Swiss::Controller::Pairing;

# Last Edit: 2014 Oct 20, 12:38:05 PM
# $Id$

use strict;
use warnings;
use parent 'Catalyst::Controller';

use List::MoreUtils qw/none any all notall/;
use Scalar::Util qw/blessed/;
use Try::Tiny;
use IO::All;
use Games::Tournament::Contestant::Swiss;
use Games::Tournament::Swiss;
use Grades;
use Net::FTP;

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
	my $tournament = $c->model('DB::Tournaments')->find(
		{ id => $tourid });
	my $rounds = $tournament->rounds;
	my $round = $tournament->round->value;
	my $members = $tournament->members;
	my @columns = Swiss::Schema::Result::Players->columns;
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
	for my $field ( qw/pairingnumber score/ ) {
		$members->reset;
		my $fieldhistory;
		while ( my $member = $members->next ) {
			my $player = $member->profile;
			my $value = $member->$field->value;
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
			for my $select ( keys %$params ) {
				next if $select eq 'Submit';
				my ( $table, $white, $black ) = split ':', $select;
				my ( $whiteplay, $blackplay ) = split ':', $params->{$select};
				my ( $game, $float, $win, $forfeit, $late );
				$game->{tournament} = $tourid;
				$game->{round} = $round;
				$game->{pair} = $table;
				$game->{white} = $white;
				$game->{black} = $black;
				if ( $whiteplay eq 'draw' and $blackplay eq 'draw' ) {
					$game->{win} = 'Both';
				}
				elsif ( $whiteplay eq 'win' ) { $game->{win} = 'White' }
				elsif ( $blackplay eq 'win' ) { $game->{win} = 'Black' }
				else { $game->{win} = 'None' }
				if ( $whiteplay eq 'forfeit' and $blackplay eq 'forfeit') {
					$game->{forfeit} = 'Both';
				}
				elsif ($whiteplay eq 'forfeit') { $game->{forfeit} = 'White' }
				elsif ($blackplay eq 'forfeit') { $game->{forfeit} = 'Black' }
				else { $game->{forfeit} = 'None' }
				push @$games, $game;
			}
			( my $leagueid = $tournament ) =~
				s/^([[:alpha:]]+[[:digit:]]+).*$/$1/;
			my $league = League->new( leagues =>
				$c->config->{leagues}, id => $leagueid );
			my $grade = Grades->new({ league => $league })->grades;
			my $ratingset = $c->model('DB::Ratings');
			$latestscores = $c->model('GTS')->assignScores( $tourney, $pairingtable, $params);
			$pairingtable->{score} = $latestscores;
			my $scoreset = $c->model('DB::Scores');
			for my $player ( @{ $tourney->entrants } ) {
				next if $player->absent;
				## TODO
				#$ratingset->update_or_create( {
				#	tournament => $tourid, player => $id,
				#	value => $latestscores->{$id} } );
				my $id = $player->id;
				$player->score( $latestscores->{$id} );
				$scoreset->update_or_create( {
					tournament => $tourid, player => $id,
					value => $latestscores->{$id} } );
			}
			my $scorestring;
			$scorestring = join '&', map { $latestscores->{$_} }
				map { $_->{id} } @playerlist if
				all { defined } values %$latestscores;
		}
	}
	$c->stash->{round} = $round;
	$c->stash->{roles} = $c->model('GTS')->roles;
	$c->stash->{games} = $games;
	unless ( defined $latestscores and all { defined } values %$latestscores) {
		$c->stash->{error_msg} = "Can't pair Round " . ($round+1) .
			" with unfinished games in Round $round.";
		$c->stash->{template} = "cards.tt2";
		return;
	}
	my $cardset = $c->model( "DB::Matches" );
	my $n = 0;
	for my $game ( @$games ) {
		$cardset->update_or_create( $game );
	}
	#my $newhistory = ( $games and ref $games eq 'ARRAY' ) ?
	#	$c->model('GTS')->changeHistory($tourney, $pairingtable,
	#			$games) : $pairingtable;
	#for my $field ( qw/pairingnumber / ) {
	#	my $Fields = ucfirst $field . 's';
	#	my $fieldset = $c->model( "DB::$Fields" );
	#	$members->reset;
	#	while ( my $member = $members->next ) {
	#		my $id = $member->profile->id;
	#		my $fieldhistory = $newhistory->{$field}->{$id};
	#		$fieldset->update_or_create( {
	#			tournament => $tourid,
	#			player => $id, 
	#			value => $fieldhistory
	#		} );
	#	}
	#}
	#for my $field ( qw/opponent role float/ ) {
	#	my $Fields = ucfirst $field . 's';
	#	my $fieldset = $c->model( "DB::$Fields" );
	#	$members->reset;
	#	while ( my $member = $members->next ) {
	#		my $id = $member->profile->id;
	#		my $fieldhistory = $newhistory->{$field}->{$id};
	#		my %series = map { ($_+1) => $fieldhistory->[$_] }
	#				0 .. $#$fieldhistory;
	#		for my $round ( keys %series ) {
	#			$fieldset->update_or_create( {
	#				tournament => $tourid,
	#				player => $id, 
	#				round => $round,
	#				$field => $series{$round}
	#			} );
	#		}
	#	}
	#}
	#@playerlist = buildPairingtable( $c, $tourid, \@playerlist,
	#	$newhistory );
	#$c->stash->{pairtable} = \@playerlist;
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
			->value;
	$round++;
	my $tournament = $c->model('DB::Tournaments')->find(
		{ id => $tourid });
	my $rounds = $tournament->rounds;
	my $members = $tournament->members;
	my @columns = Swiss::Schema::Result::Players->columns;
	my ($latestscores, $pairingtable);
	for my $field ( qw/score/ ) {
		my $fieldhistory;
		while ( my $member = $members->next ) {
			my $player = $member->profile;
			my $row = $member->$field;
			my $value = $row? $row->value: 0;
			$fieldhistory->{$player->id} = $value;
		}
		$pairingtable->{$field} = $fieldhistory;
	}
	my (@playerlist, @absentees);
		$members->reset;
	while ( my $member = $members->next ) {
		my $player = { map { $_ => $member->profile->$_ } @columns };
		$player->{firstround} = $member->firstround;
		my $rating = $member->profile->rating->find({
				tournament => $tourid, round => $round-1 });
		my $value;
		try { $value = $rating->value; }
			catch { warn "No rating for $player->{id}: $_"; };
		$player->{rating} = $value;
		$player->{score} = $pairingtable->{score}->{ $player->{id} };
		push @playerlist, $player;
		push @absentees, $player if $member->absent eq 1;
	}
	my $tourney = $c->model( 'SetupTournament', {
			name => $tourid,
			round => ( $round - 1 ),
			rounds => $rounds,
			entrants => \@playerlist,
			absentees => \@absentees,
		} );
	my @matches;
	my $matches = $tournament->matches;
	while ( my $match = $matches->next ) {
		push @matches, $c->model('GTS')->writeCard( $tourney, $match );
	}
	for my $n ( 0 .. $#playerlist ) {
		my $id = $playerlist[$n]->{id};
		$tourney->entrants->[$n]->pairingNumber(
		$pairingtable->{pairingnumber}->{$id} );
	}
	my ($mess, $log, $games) = $c->model('GTS')->pair( {
			tournament => $tourney,
			history => \@matches } );
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
	my $cardset = $c->model( "DB::Matches" );
	for my $game ( @$games ) {
		my $card = $c->model('GTS')->cardData( $game );
		$cardset->update_or_create( {
			tournament => $tourid,
			round => $round,
			pair => $n++, 
			white => $card->{white},
			black => $card->{black},
			float => $card->{float},
			win => $card->{win},
			forfeit => $card->{forfeit},
			tardy => $card->{tardy}
				} );
	}
	$round = $tourney->round;
	$c->session->{"${tourid}_round"} = $round;
	$c->model('DB::Round')->find({ tournament => $tourid })->update({
			value=>$round });
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
	$c->detach('ftp');
}


=head2 ftp

	$self->forward('ftp')

Private method used by pairing, draw actions to put pairing on http://web.nuu.edu.tw/~greg/$genre/draw/$tourid.html

=cut

sub ftp : Private {
	my ($self, $c, $round) = @_;
	my $ftp = Net::FTP->new('web.nuu.edu.tw');
	$ftp->login('greg', '');
	$ftp->binary;
	my $config = $c->config;
	my $leaguedirs = $config->{leagues};
	my %leaguesByGenre;
	my @genres = qw/conversation business friends customs media multimedia college literature intercultural/;
	$leaguesByGenre{$_} = $config->{ $_ } for @genres;
	my %leaguegenre = map { my $genre = $_ ;  my $leagues = $leaguesByGenre{$genre};
						map { $_ => $genre } @$leagues } @genres;
	my $tourid = $c->stash->{tournament};
	my $genre = $leaguegenre{$tourid};
	$ftp->cwd("/public_html/$tourid/");
	my $drawfile = "$leaguedirs/$tourid/comp/draw.html";
	io($drawfile)->print
		( $c->view('TT')->render($c, 'draw.tt2') );
	$ftp->put($drawfile, "draw.html");
	$c->response->redirect
		("http://web.nuu.edu.tw/~greg/$tourid/draw.html");
}

=head2 draw

	http://sac.nuu.edu.tw/swiss/pairing/draw/17

Need to be able to go back and look at draws without writing database or doing another pairing. Adds 'win', 'forfeit' info unless 'Unknown'.

=cut

sub draw : Local {
        my ($self, $c, $round) = @_;
	my $tourid = $c->session->{tournament};
	$round ||= $c->model('DB::Round')->find( { tournament => $tourid } )
			->value;
	my $tournament = $c->model('DB::Tournaments')->find(
		{ id => $tourid });
	my $members = $tournament->members;
	my @columns = Swiss::Schema::Result::Players->columns;
	my (%playerlist, @absentees);
	while ( my $member = $members->next ) {
		my $player = { map { $_ => $member->profile->$_ } @columns };
		$player->{firstround} = $member->firstround;
		my $rating = $member->profile->rating->find({
				tournament => $tourid, round => $round-1 });
		my $value;
		try { $value = $rating->value; }
			catch { warn "No rating for $player->{id}: $_"; };
		$player->{rating} = $value || 0;
		my $score;
		try { $score = $member->score->value; }
			catch { warn "No score for $player->{id}: $_"; };
		$player->{score} = $score || 0;
		$playerlist{ $player->{id} } = $player;
		push @absentees, $player if $member->absent eq 'True';
	}
	my $Roles = $c->model('GTS')->roles;
	my @roles = map { lcfirst $_ } @$Roles;
	my $matches = $tournament->matches->search({ round => $round });
	my %games;
	while ( my $match = $matches->next ) {
		my %contestants;
		if ( $match->black eq 'Bye' ) {
			my $byer = $match->white;
			$contestants{Bye} = $playerlist{ $byer };
		}
		else {
			%contestants = map { ucfirst($_) =>
				$playerlist{ $match->$_ } } @roles;
		}
		my $table = $match->pair;
		$games{$table} = {contestants => \%contestants,
				win => $match->win,
				forfeit => $match->forfeit };
	}
	my @games = map $games{$_}, sort {$a<=>$b} keys %games;
	$c->stash->{tournament} = $tourid;
	$c->stash->{round} = $round;
	$c->stash->{roles} = $Roles;
	$c->stash->{games} = \@games;
	$c->stash->{template} = "draw.tt2";
	$c->detach('ftp');
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
