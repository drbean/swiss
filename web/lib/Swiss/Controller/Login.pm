package Swiss::Controller::Login;

use strict;
use warnings;
use parent 'Catalyst::Controller';

=head1 NAME

dic::Controller::Login - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

Arbiter login. If arbiter has more than one tournament, find out the one being arbited now.

=cut

sub index :Path :Args(0)  {
    my ( $self, $c ) = @_;
    my $id       = $c->request->params->{id}       || "";
    my $name     = $c->request->params->{name}     || "";
    my $password = lc $c->request->params->{password} || "";
    if ( $id && $name && $password ) {
        if ( $c->authenticate( { id => $id, password => $password } ) ) {
            $c->session->{arbiter_id} = $id;
	    my $arbiter = $c->model('DB::Arbiters')->find( { id => $id } );
	    my $tournament = $arbiter->active;
	    my $tourid = $tournament->id if $tournament;
	    my @tournaments = $arbiter->tournaments;
	    $c->stash->{id}         = $id;
	    $c->stash->{name}       = $name;
	    $c->stash->{recentone}   = $tourid;
	    $c->stash->{tournaments}   = \@tournaments;
	    $c->stash->{template}   = 'swiss.tt2';
	    return;
        }
        else {
            $c->stash->{error_msg} = "Bad username or password.";
        }
    }
    else {
        $c->stash->{error_msg} = "You need id, name and password.";
    }
    $c->stash->{template} = 'login.tt2';
}

=head2 tournament

Find tournament multi-tournament arbiter is arbiting.

=cut

sub tournaments : Local {
	my ($self, $c) = @_;
	my $league = $c->request->params->{league} || "";
	my $password = $c->request->params->{password} || "";
	$c->session->{league} = $league;
	$c->session->{exercise} = undef;
	$c->response->redirect( $c->uri_for("/exercises/list") );
	return;
}


=head1 AUTHOR

Dr Bean,,,

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;

# vim: set ts=8 sts=4 sw=4 noet:
