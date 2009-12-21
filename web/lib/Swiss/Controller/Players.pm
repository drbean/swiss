package dic::Controller::Players;

use strict;
use warnings;
use parent 'Catalyst::Controller';

=head1 NAME

dic::Controller::Players - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 list

Fetch all Player objects and pass to players/list.tt2 in stash to be displayed

=cut
 
sub list : Local {
    # Retrieve the usual perl OO '$self' for this object. $c is the Catalyst
    # 'Context' that's used to 'glue together' the various components
    # that make up the application
    my ($self, $c) = @_;

    # Retrieve all of the Player records as Player model objects and store in
    # stash where they can be accessed by the TT template
    $c->stash->{players} = [$c->model('DB::Player')->all];
    
    # Set the TT template to use.  You will almost always want to do this
    # in your action methods (actions methods respond to user input in
    # your controllers).
    $c->stash->{template} = 'players/list.tt2';
}


=head2 url_create

Create a player with the supplied id, name, and password

=cut

sub url_create : Local {
	my ($self, $c, $id, $name, $password, @leagueids ) = @_;
	my $player = $c->model('DB::Player')->update_or_create({
	       id => $id,
		name  => $name,
	       password => $password
	   });
	$player->add_to_member({league => $_}) for @leagueids;
	$c->stash->{player} = $player;
	$c->stash->{template} = 'players/create_done.tt2';
}


=head2 form_create

Display form to collect information for player to create

=cut

sub form_create : Local {
	my ($self, $c) = @_;

# Set the TT template to use
	$c->stash->{template} = 'players/form_create.tt2';
}


=head2 form_create_do

Take information from form and add to database

=cut

sub form_create_do : Local {
	my ($self, $c) = @_;

# Retrieve the values from the form
	my $id     = $c->request->params->{id}     || 'N/A';
	my $name     = $c->request->params->{name}     || 'N/A';
	my $password    = $c->request->params->{password}    || 'N/A';
	my $league    = $c->request->params->{league}    || 'N/A';

# Create the player
	my $player = $c->model('DB::Player')->create({
		id => $id,
	       name   => $name,
	       password => $password,
	   });
# Handle relationship with author
	$player->add_to_member({league => $league});

# Store new model object in stash
	$c->stash->{player} = $player;

# Avoid Data::Dumper issue mentioned earlier
# You can probably omit this
	$Data::Dumper::Useperl = 1;

# Set the TT template to use
	$c->stash->{template} = 'players/create_done.tt2';
}


=head2 delete

Delete a player

=cut

	sub delete : Local {
	my ($self, $c, $id) = @_;
	$c->model('DB::Player')->search({id => $id})->delete_all;
	$c->stash->{status_msg} = "Player deleted.";
       $c->response->redirect($c->uri_for('/players/list',
                   {status_msg => "Player deleted."}));
}


=head1 AUTHOR

Dr Bean,,,

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
