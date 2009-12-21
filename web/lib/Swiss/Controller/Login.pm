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
        my $username = $id;
        if ( $c->authenticate( { id => $username, password => $password } ) ) {
            $c->session->{arbiter_id} = $id;
            my @tournaments =
              $c->model("DB::Tournaments")->search( { arbiter => $id } )->
	      	get_column('id');
            unless ( @tournaments <= 1 ) {
                $c->stash->{id}         = $id;
                $c->stash->{name}       = $name;
                $c->stash->{tournaments}   = \@tournaments;
                $c->stash->{template}   = 'tournaments.tt2';
                return;
            }
            else {
                $c->session->{tournament}   = $tournaments[0];
		if ( defined $c->session->{round}) {
			my $round = $c->session->{round};
			$c->response->redirect(
				$c->uri_for( "/play/update/$round" ) );
		}
		else {
			$c->response->redirect( $c->uri_for("/exercises/list") );
		}
                return;
            }
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

=head2 official

Set league official is organizing. Use session player_id to authenticate the participant.

=cut

sub official : Local {
	my ($self, $c) = @_;
	my $league = $c->request->params->{league} || "";
	my $password = lc $c->request->params->{password} || "";
        my $username = $c->session->{player_id};
        if ( $c->authenticate( {id =>$username, password=>$password} ) ) {
		# my $officialrole = "official";
		my $officialrole = 1;
		if ( $c->check_user_roles($officialrole) ) {
			$c->session->{league} = $league;
			$c->response->redirect($c->uri_for("/exercises/list"));
			return;
		}
		else {
		# Set an error message
		$c->stash->{error_msg} = "Bad username or password?";
		$c->stash->{template} = 'login.tt2';
		}
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
