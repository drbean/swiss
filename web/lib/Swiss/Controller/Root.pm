package Swiss::Controller::Root;

use strict;
use warnings;
use parent 'Catalyst::Controller';

use List::MoreUtils qw/all notall/;

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
}


=head2 name

Tournament name

=cut

sub name : Local {
        my ($self, $c) = @_;
	my $tournament = $c->request->params->{tournament};
	$c->stash->{tournament} = $tournament;
	$c->response->cookies->{tournament} = { value => $tournament };
	$c->stash->{template} = 'players.tt2';
}


=head2 add_player

First round, players, number of rounds

=cut

sub add_player : Local {
        my ($self, $c) = @_;
	my $cookies = $c->request->cookies;
	my $tourney = $c->request->cookie('tournament')->value;
	my @playerlist = $c->model('GTS')->turnIntoPlayers($tourney, $cookies);
	$c->stash->{tournament} = $tourney;
	if (  $c->request->params->{stop} ) {
		$c->stash->{template} = 'rounds.tt2';
		return;
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
			$tourney, \@playerlist);
		$c->response->cookies->{$_} = { value => $cookies{$_ } }
			for keys %cookies;
	}
	$c->stash->{template} = 'players.tt2';
}



=head2 edit_players

First round, players, number of rounds

=cut

sub edit_players : Local {
        my ($self, $c) = @_;
	my $cookies = $c->request->cookies;
	my $tourney = $c->request->cookie('tournament')->value;
	my $newlist = $c->request->params->{playerlist};
	my @playerlist = $c->model('GTS')->parsePlayers($tourney, $newlist);
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
			$tourney, \@playerlist);
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
	my $tourney = $c->request->cookie('tournament')->value;
	my $rounds = $c->request->params->{rounds};
	$c->response->cookies->{"${tourney}_rounds"} = { value => $rounds };
	$c->stash->{rounds} = $rounds;
	$c->detach('pair');
}


=head2 pair

Pair first round

=cut

sub pair : Local {
        my ($self, $c) = @_;
	my $cookies = $c->request->cookies;
	my $tourney = $c->request->cookie('tournament')->value;
	my @playerlist = $c->model('GTS')->turnIntoPlayers($tourney, $cookies);
	my $rounds = $c->stash->{"${tourney}_rounds"};
	my @games = $c->model('GTS')->pair( {rounds => $rounds, entrants => \@playerlist} );
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
