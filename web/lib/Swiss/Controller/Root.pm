package Swiss::Controller::Root;

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

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    # Hello World
    $c->response->body( $c->welcome_message );
}

sub default :Path {
    my ( $self, $c ) = @_;
    $c->response->body( 'Page not found' );
    $c->response->status(404);
}


=head2 swiss

Request a pairing of a tournament

=cut 

sub swiss : Local {
	my ($self, $c) = @_;
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
	$c->response->cookies->{tournament} = { value => $tourname };
	if ( @tournames == 0 or none { $tourname eq $_ } @tournames ) {
		push @tournames, $tourname;
		my $cookie = $c->model('GTS')->stringifyCookie(@tournames) 
			if @tournames;
		$c->response->cookies->{tournaments} = { value => $cookie };
		$c->response->cookies->{"${tourname}_round"} = { value => 0 };
		$c->stash->{template} = 'players.tt2';
		return;
	}
	else {
		$c->detach( 'edit_players' );
	}
}


=head2 add_player

First round, players, number of rounds. Spaghetti code in deciding what to do after stop? Make it public, conversational! Noticeable, top level!

=cut

sub add_player : Local {
        my ($self, $c) = @_;
	my $cookies = $c->request->cookies;
	my $tourname = $c->request->cookie('tournament')->value;
	my $round = $c->request->cookie("${tourname}_round")->value + 1;
	my @playerlist = $c->model('GTS')->turnIntoPlayers($tourname, $cookies);
	$c->stash->{tournament} = $tourname;
	if (  $c->request->params->{stop} ) {
		if ( $c->request->cookie("${tourname}_rounds") and
			$c->request->cookie("${tourname}_rounds")->isa(
				'CGI::Simple::Cookie') )
		{
			$c->response->redirect("pairingtable");
		}
		else {
			$c->stash->{template} = 'rounds.tt2';
			return;
		}
	}
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
		my %cookies = $c->model('GTS')->turnIntoCookies(
			$tourname, \@playerlist);
		$c->response->cookies->{$_} = { value => $cookies{$_ } }
			for keys %cookies;
	}
	$c->stash->{round} = $round;
	$c->stash->{template} = 'players.tt2';
}



=head2 edit_players

Later rounds, players

=cut

sub edit_players : Local {
        my ($self, $c) = @_;
	my $tournament = $c->stash->{tournament};
	my $cookies = $c->request->cookies;
	my $tourname = $c->request->cookie('tournament')->value;
	my $round = $c->request->cookie("${tourname}_round")->value + 1;
	my @playerlist;
	if ( my $newlist = $c->request->params->{playerlist} ) {
		@playerlist = $c->model('GTS')->parsePlayers(
			$tourname, $newlist);
	}
	else {
		my $cookies = $c->request->cookies;
		my $tourname = $c->request->cookie('tournament')->value;
		@playerlist = $c->model('GTS')->turnIntoPlayers(
			$tourname, $cookies);
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
		my %cookies = $c->model('GTS')->turnIntoCookies(
			$tourname, \@playerlist);
		$c->response->cookies->{$_} = { value => $cookies{$_ } }
			for keys %cookies;
		$c->stash->{playerlist} = \@playerlist;
	}
	$c->stash->{round} = $round;
	$c->stash->{template} = 'players.tt2';
}


=head2 rounds

Number of rounds

=cut

sub rounds : Local {
        my ($self, $c) = @_;
	my $tourname = $c->request->cookie('tournament')->value;
	my $rounds = $c->request->params->{rounds};
	$c->response->cookies->{"${tourname}_rounds"} = { value => $rounds };
	$c->stash->{rounds} = $rounds;
	$c->response->redirect('nextround');
}


=head2 pairingtable

Offer pairing table for later rounds 

=cut

sub pairingtable : Local {
        my ($self, $c) = @_;
	my $cookies = $c->request->cookies;
	my $tourname = $c->request->cookie('tournament')->value;
	my $round = ( $c->request->cookie("${tourname}_round") and
		$c->request->cookie("${tourname}_round")->isa(
			'CGI::Simple::Cookie') ) ?
		$c->request->cookie("${tourname}_round")->value + 1: 1;
	my @playerlist = $c->model('GTS')->turnIntoPlayers($tourname, $cookies);
	my %pairingtable = $c->model('GTS')->readHistory(
				$tourname, \@playerlist, $cookies, $round);
	for my $player ( @playerlist ) {
		my $id = $player->{id};
		for my $historytype ( qw/opponent role float score/ ) {
			my $run = $pairingtable{$historytype}->{$id};
			$player->{$historytype} = $run;
		}
	}
	$c->stash->{round} = $round;
	$c->stash->{playerlist} = \@playerlist;
	$c->stash->{template} = "pairtable.tt2";
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
	my %pairingtable;
	if ( $c->request->params->{pairingtable} ) {
		my $table = $c->request->params->{pairingtable};
		%pairingtable = $c->model('GTS')->parseTable($tourney, $table);
	}
	else {
		my %history = $c->model('GTS')->readHistory(
				$tourname, \@playerlist, $cookies, $round-1);
		if ( exists $c->request->params->{Submit} and
			$c->request->params->{Submit} eq "Pair round $round" ) {
			my $params = $c->request->params;
			my $scores = $c->model('GTS')->assignScores(
				$tourney, \%history, $params);
			my $scorestring = join '&', @$scores;
			$c->response->cookies->{"${tourname}_scores"} =
				{ value => $scorestring };
			$c->response->redirect('nextround');
			return;
		}
		else { %pairingtable = %history; }
	}
	my ($mess, $games) = $c->model('GTS')->pair( {
			tournament => $tourney,
			history => \%pairingtable } );
$DB::single=1;
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
	my %cookies = $c->model('GTS')->historyCookies( $tourney, $newhistory);
	$c->response->cookies->{$_} = {value => $cookies{$_}} for keys %cookies;
	$round = $tourney->round;
	$c->response->cookies->{"${tourname}_round"} = { value => $round };
	$c->stash->{round} = $round;
	$c->stash->{roles} = $c->model('GTS')->roles;
	$c->stash->{games} = $games;
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
