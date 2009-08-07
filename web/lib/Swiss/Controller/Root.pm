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

Tournament name. Set 'tournaments' cookie.

=cut

sub name : Local {
        my ($self, $c) = @_;
	my $tourname = $c->request->params->{tournament};
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
	my $round = $c->request->cookie("${tourname}_round")->value;
	my @playerlist = $c->model('GTS')->turnIntoPlayers($tourname, $cookies);
	$c->stash->{tournament} = $tourname;
	if (  $c->request->params->{stop} ) {
		if ( $c->request->cookie("${tourname}_rounds") and
			$c->request->cookie("${tourname}_rounds")->isa(
				'CGI::Simple::Cookie') )
		{
			$c->detach("pairtable");
		}
		else {
			$c->stash->{template} = 'rounds.tt2';
			return;
		}
	}
	my %entrant = map { $_ => $c->request->params->{$_} }
							qw/id name rating/;
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
	my $round = $c->request->cookie("${tourname}_round")->value;
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
	$c->stash->{round} = $round;
	$c->stash->{template} = 'players.tt2';
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
	$c->detach('nextround');
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
		$c->request->cookie("${tourname}_round")->value: 0;
	my @playerlist = $c->model('GTS')->turnIntoPlayers($tourname, $cookies);
$DB::single=1;
	my %pairingtable = $c->model('GTS')->readHistory(
				$tourname, \@playerlist, $cookies, $round);
	my $rounds = $c->stash->{rounds};
	my $tourney = $c->model('GTS')->setupTournament( {
			name => $tourname,
			round => $round,
			rounds => $rounds,
			entrants => \@playerlist });
	my @games = $c->model('GTS')->pair( {
			tournament => $tourney,
			history => \%pairingtable } );
	$c->model('GTS')->changeHistory(
			$tourney, \%pairingtable, \@games );
	my %prefFloatcookies =
		$c->model('GTS')->historyCookies( $tourney, \%pairingtable);
	$c->response->cookies->{$_} = { value => $prefFloatcookies{$_} }
			for keys %prefFloatcookies;
	$round = $tourney->round;
	$c->response->cookies->{"${tourname}_round"} = { value => $round };
	$c->stash->{round} = $round;
	$c->stash->{roles} = $c->model('GTS')->roles;
	$c->stash->{games} = \@games;
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
