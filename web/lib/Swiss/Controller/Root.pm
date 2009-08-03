package Swiss::Controller::Root;

use strict;
use warnings;
use parent 'Catalyst::Controller';

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


=head2 players

First round, players, number of rounds

=cut

sub players : Local {
        my ($self, $c) = @_;
	$c->stash->{tournament} = $c->request->cookie('tournament')->value;
	my %cookies = ( id => undef, name => undef, rating => undef );
	for my $key ( qw/id name rating/ ) {
		if ( defined $c->request->cookie($key) ) {
			my @cookies = $c->request->cookie($key)->value;
			$cookies{$key} = \@cookies;
		}
	}
	my $playerN = ref $cookies{id} eq 'ARRAY'? @{ $cookies{id} }: 0;
	my @playerlist = map { { id => $cookies{id}->[$_],
				name => $cookies{name}->[$_],
				rating => $cookies{rating}->[$_] } }
				0 .. $playerN-1;
	my %entrant = map { $_ => $c->request->params->{$_} }
							qw/id name rating/;

	for my $key ( qw/id name rating/ ) {
		my $cookie = $cookies{$key};
		push @$cookie, $entrant{$key};
		$c->response->cookies->{$key} = { value => $cookie };
	}
	push @playerlist, \%entrant;
$DB::single=1;
	$c->stash->{playerlist} = \@playerlist;
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
