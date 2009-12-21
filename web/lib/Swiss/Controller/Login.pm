package dic::Controller::Login;

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

Login logic. We used to let "guest"s in without a password, or ID and also redirect to exercise list. Now we redirect to the exercise, if it appears as the one argument.

=cut

sub index :Path :Args(0)  {
    my ( $self, $c ) = @_;
    my $id       = $c->request->params->{id}       || "";
    my $name     = $c->request->params->{name}     || "";
    my $password = lc $c->request->params->{password} || "";
    if ( $id && $name && $password ) {
        my $username = $id;
        if ( $c->authenticate( { id => $username, password => $password } ) ) {
            $c->session->{player_id} = $id;
            $c->session->{question} = undef;
            my $officialrole = 1;
            if ( $c->check_user_roles($officialrole) ) {
                $c->stash->{id}   = $id;
                $c->stash->{name} = $name;
                $c->stash->{leagues} =
                  [ $c->model('DB::League')->search( {} ) ];
                $c->stash->{template} = 'official.tt2';
                return;
            }
            my @memberships =
              $c->model("DB::Member")->search( { player => $id } );
            my @leagues;
            for my $membership (@memberships) {
                push @leagues, $membership->league;
            }
            unless ( @leagues == 1 ) {
                $c->stash->{id}         = $id;
                $c->stash->{name}       = $name;
                $c->stash->{leagues}   = \@leagues;
                $c->stash->{template}   = 'membership.tt2';
                return;
            }
            else {
                $c->session->{league}   = $leagues[0]->id;
		if ( defined $c->session->{exercise}) {
			my $exercise = $c->session->{exercise};
			$c->response->redirect(
				$c->uri_for( "/play/update/$exercise" ) );
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


=head2 membership

Set league multi-membership player is participating in.

=cut

sub membership : Local {
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
