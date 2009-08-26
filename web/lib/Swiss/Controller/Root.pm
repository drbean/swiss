package Swiss::Controller::Root;

# Last Edit: 2009  8月 26, 17時04分14秒
# $Id$

use strict;
use warnings;
use parent 'Catalyst::Controller';

use List::MoreUtils qw/none any all notall/;

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config->{namespace} = '';

=head1 NAME

Swiss::Controller::Root - Root Controller for Swiss

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=cut

=head2 index

=cut


sub default :Path {
    my ( $self, $c ) = @_;
    $c->response->body( 'Page not found' );
    $c->response->status(404);
}


=head2 index

Request a pairing of a tournament

=cut 

sub index :Path :Args(0) {
	my ( $self, $c ) = @_;
	my ($lasttourney, $tourneychoice, @tournaments);
	if ( $c->request->cookie('tournament') and
		$c->request->cookie('tournament')->isa('CGI::Simple::Cookie') )
	{
		$lasttourney = $c->request->cookie('tournament')->value;
	}
	if ( $c->request->cookie('tournaments') and
		$c->request->cookie('tournaments')->isa('CGI::Simple::Cookie') )
	{
		$tourneychoice = $c->request->cookie('tournaments')->value;
		@tournaments = $c->model('GTS')->destringCookie($tourneychoice);
	}
	$c->stash->{recentone} = $lasttourney;
	$c->stash->{tournaments} = \@tournaments;
	$c->stash->{template} = "swiss.tt2";
	return;
    # Hello World
    $c->response->body( $c->welcome_message );
}


=head2 name

Tournament name. Set 'tournament' and reset 'tournaments' cookie. Set 'tournament_round' cookie to 0. But remember, Not everyone agrees about what round it is.

=cut

sub name : Local {
        my ($self, $c) = @_;
	my $tourname = $c->request->params->{tournament};
	unless ( $tourname ) {
		$c->stash->{error_msg} = "What is the tournament's name?";
		$c->stash->{template} = 'swiss.tt2';
		return;
	}
	my @tournames;
	if ( $c->request->cookie('tournaments') and
		$c->request->cookie('tournaments')->isa('CGI::Simple::Cookie') )
	{
		my $tourneychoice = $c->request->cookie('tournaments')->value;
		@tournames = $c->model('GTS')->destringCookie($tourneychoice);
	}
	$c->stash->{tournament} = $tourname;
	setCookie( $c, tournament => $tourname );
	if ( @tournames == 0 or none { $tourname eq $_ } @tournames ) {
		push @tournames, $tourname;
		my $strungnames = $c->model('GTS')->stringifyCookie(@tournames) 
			if @tournames;
		setCookie( $c, tournaments => $strungnames );
		setCookie( $c, "${tourname}_round" => 0 );
		$c->stash->{template} = 'players.tt2';
		return;
	}
	else {
		$c->detach( 'edit_players' );
	}
}


=head2 add_player

First round, players. IDs, names and ratings are limited to 7, 20 and 4 characters, respectively.

=cut

sub add_player : Local {
        my ($self, $c) = @_;
	my $cookies = $c->request->cookies;
	my $tourname = $c->request->cookie('tournament')->value;
	my $round = $c->request->cookie("${tourname}_round")->value + 1;
	my @playerlist = $c->model('GTS')->turnIntoPlayers($tourname, $cookies);
	$c->stash->{tournament} = $tourname;
	my %entrant = map { $_ => $c->request->params->{$_} }
							qw/id name rating/;
	$entrant{firstround} = $round;
	my $mess;
	if ( $mess = $c->model('GTS')->allFieldCheck( \%entrant ) ) {
		$c->stash->{error_msg} = $mess;
		$c->stash->{playerlist} = \@playerlist;
	}
	elsif ( $mess = $c->model('GTS')->idDupe(@playerlist, \%entrant ) ) {
		$c->stash->{error_msg} = $mess;
		$c->stash->{playerlist} = \@playerlist;
	}
	else {
		push @playerlist, \%entrant;
		$c->stash->{playerlist} = \@playerlist;
		my %cookedPlayers = $c->model('GTS')->turnIntoCookies(
			$tourname, \@playerlist);
		setCookie( $c, %cookedPlayers );
	}
	$c->stash->{round} = $round;
	$c->stash->{template} = 'players.tt2';
}


=head2 edit_players

Later rounds, players

=cut

sub edit_players : Local {
        my ($self, $c) = @_;
	my $cookies = $c->request->cookies;
	my $tourname = $c->request->cookie('tournament')->value;
	my $round = $c->request->cookie("${tourname}_round")->value + 1;
	my @playerlist;
	if ( my $newlist = $c->request->params->{playerlist} ) {
		@playerlist = $c->model('GTS')->parsePlayers(
			$tourname, $newlist);
	}
	else {
		@playerlist = $c->model('GTS')->turnIntoPlayers(
			$tourname, $cookies);
	}
	for my $player ( @playerlist ) {
		$player->{firstround} ||= $round;
	}
	my $mess;
	if ( $mess = $c->model('GTS')->allFieldCheck(@playerlist ) ) {
		$c->stash->{error_msg} = $mess;
		$c->stash->{playerlist} = \@playerlist;
	}
	elsif ( $mess = $c->model('GTS')->idDupe(@playerlist ) ) {
		$c->stash->{error_msg} = $mess;
		$c->stash->{playerlist} = \@playerlist;
	}
	else {
		my %cookedPlayers = $c->model('GTS')->turnIntoCookies(
			$tourname, \@playerlist);
		setCookie( $c, %cookedPlayers );
		$c->stash->{playerlist} = \@playerlist;
	}
	$c->stash->{round} = $round;
	$c->stash->{template} = 'players.tt2';
}


=head2 final_players

Finish editing players

=cut

sub final_players : Local {
        my ($self, $c) = @_;
	my $cookies = $c->request->cookies;
	my $tourname = $c->request->cookie('tournament')->value;
	my $round = $c->request->cookie("${tourname}_round")->value + 1;
	my @players = $c->model('GTS')->turnIntoPlayers($tourname, $cookies);
	if ( $c->request->cookie("${tourname}_rounds") and
		$c->request->cookie("${tourname}_rounds")->isa(
			'CGI::Simple::Cookie') )
	{
		my %histories = $c->model('GTS')->readHistory(
				$tourname, \@players, $cookies, $round);
		my @pairingtable = buildPairingtable(
			$c, $tourname, \@players, \%histories );
		$c->stash->{tournament} = $tourname;
		$c->stash->{round} = $round;
		$c->stash->{playerlist} = \@pairingtable;
		$c->stash->{template} = "pairtable.tt2";
	}
	else {
		my $playerNumber = @players % 2? @players: $#players;
		$c->stash->{tournament} = $tourname;
		$c->stash->{rounds} = $playerNumber;
		$c->stash->{template} = 'rounds.tt2';
	}
}


=head2 rounds

Number of rounds

=cut

sub rounds : Local {
        my ($self, $c) = @_;
	my $tourname = $c->request->cookie('tournament')->value;
	my $round = $c->request->cookie('round') ?
				$c->request->cookie('round')->value : 1;
	my $rounds = $c->request->params->{rounds};
	setCookie( $c, "${tourname}_rounds" => $rounds );
	$c->stash->{tournament} = $tourname;
	$c->stash->{rounds} = $rounds;
	$c->stash->{round} = $round;
	$c->stash->{template} = 'preppair.tt2';
}


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
	my $cookies = $c->request->cookies;
	my $tourname = $c->request->cookie('tournament')->value;
	my $round = ( $c->request->cookie("${tourname}_round") and
		$c->request->cookie("${tourname}_round")->isa(
			'CGI::Simple::Cookie') ) ?
		$c->request->cookie("${tourname}_round")->value : 1;
	my $rounds = $c->stash->{rounds};
	my @playerlist = $c->model('GTS')->turnIntoPlayers($tourname, $cookies);
	my $tourney = $c->model('GTS')->setupTournament( {
			name => $tourname,
			round => $round,
			rounds => $rounds,
			entrants => \@playerlist });
	my ($games, $latestscores, %pairingtable);
	%pairingtable = $c->model('GTS')->readHistory(
			$tourname, \@playerlist, $cookies, $round);
	for my $n ( 0 .. $#playerlist ) {
		my $id = $playerlist[$n]->{id};
		$tourney->entrants->[$n]->pairingNumber(
		$pairingtable{pairingnumber}->{$id} );
	}
	if ( $c->request->params->{pairingtable} ) {
		my $table = $c->request->params->{pairingtable};
		%pairingtable = $c->model('GTS')->parseTable($tourney, $table);
		$latestscores = $pairingtable{score};
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
	@playerlist = buildPairingtable( $c, $tourname, \@playerlist,
		$newhistory );
	$c->stash->{pairtable} = \@playerlist;
	$c->stash->{tournament} = $tourname;
	$c->stash->{round} = ++$round;
	$c->stash->{roles} = $c->model('GTS')->roles;
	$c->stash->{games} = $games;
	$c->stash->{template} = "preppair.tt2" unless 
		 $c->request->args->[0] eq 'editable';
	$c->stash->{template} = 'paireditable.tt2';
}


=head2 nextround

Pair first round

=cut

sub nextround : Local {
        my ($self, $c) = @_;
	my $cookies = $c->request->cookies;
	my $tourname = $c->request->cookie('tournament')->value;
	my $round = ( $c->request->cookie("${tourname}_round") and
		$c->request->cookie("${tourname}_round")->isa(
			'CGI::Simple::Cookie') ) ?
		$c->request->cookie("${tourname}_round")->value + 1: 1;
	my $rounds = $c->stash->{rounds};
	my @playerlist = $c->model('GTS')->turnIntoPlayers($tourname, $cookies);
	my $tourney = $c->model('GTS')->setupTournament( {
			name => $tourname,
			round => ($round -1),
			rounds => $rounds,
			entrants => \@playerlist });
	my ($latestscores, %pairingtable);
	%pairingtable = $c->model('GTS')->readHistory(
			$tourname, \@playerlist, $cookies, $round-1);
	for my $n ( 0 .. $#playerlist ) {
		my $id = $playerlist[$n]->{id};
		$tourney->entrants->[$n]->pairingNumber(
		$pairingtable{pairingnumber}->{$id} );
	}
	my ($mess, $log, $games) = $c->model('GTS')->pair( {
			tournament => $tourney,
			history => \%pairingtable } );
	if ( $mess and $mess =~ m/^All joined into one .*, but no pairings!/ or
		@$games * 2 < @playerlist ) {
		$c->stash->{error_msg} = $mess;
		$c->stash->{round} = $round - 1;
		$c->stash->{template}  = "gameover.tt2";
		return;
	}
	$tourney->round($round);
	my $newhistory = $c->model('GTS')->changeHistory(
			$tourney, \%pairingtable, $games );
	my %cookhist = $c->model('GTS')->historyCookies($tourney, $newhistory);
	setCookie( $c, %cookhist );
	$round = $tourney->round;
	setCookie( $c, "${tourname}_round" => $round );
	if ( $c->request->params->{pairtable} ) {
		@playerlist = buildPairingtable( $c, $tourname, \@playerlist, 
			$newhistory );
		$c->stash->{pairtable} = \@playerlist;
	}
	$c->stash->{tournament} = $tourname;
	$c->stash->{round} = $round;
	$c->stash->{roles} = $c->model('GTS')->roles;
	$c->stash->{games} = $games;
	$c->stash->{log} = $log if $c->request->params->{log};
	$c->stash->{template} = "draw.tt2";
}


=head2 setCookie

Used by tournament, player, history actions, interfacing with Catalyst::Response's use of CGI::Simple::Cookie.

=cut

sub setCookie {
	my $c = shift;
	my %cookies = @_;
	$c->response->cookies->{$_} = { value => $cookies{$_},
					expires => '+1M' } for keys %cookies;
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
