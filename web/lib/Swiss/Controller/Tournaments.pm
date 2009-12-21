package Swiss::Controller::Tournaments;

use Moose;
BEGIN { extends 'Catalyst::Controller'; }

use Lingua::Stem qw/stem/;
use Net::FTP;

=head1 NAME

dic::Controller::Tournaments - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 form_create

Display form to collect information for tournament to create

=cut

sub form_create : Local {
	my ($self, $c) = @_;
	$c->stash->{template} = 'tournaments/form_create.tt2';
}


=head2 list

Fetch all tournaments objects and pass to tournament/list.tt2 in stash to be displayed

=cut
 
sub list : Local {
    # Retrieve the usual perl OO '$self' for this object. $c is the Catalyst
    # 'Context' that's used to 'glue together' the various components
    # that make up the application
    my ($self, $c) = @_;
    my $arbiterid = $c->session->{arbiter_id};
    my $tournamentid = $c->session->{tournament};
    my $tournament = $c->model('DB::Tournaments')->find({id=>$tournamentid});
    # Retrieve all of the text records as text model objects and store in
    # stash where they can be accessed by the TT template
    $c->stash->{tournament} = [$c->model('DB::Tournament')->search(
	    { arbiter => $arbiterid })];
    # Set the TT template to use.  You will almost always want to do this
    # in your action methods (actions methods respond to user input in
    # your controllers).
    $c->stash->{template} = 'tournaments/list.tt2';
}


=head2 create

http://server.school.edu/dic/exercises/create/textId/exerciseType/exerciseId

Create comprehension questions and cloze exercise. If 2 different leagues have the same genre, ie their texts are the same, will creating an exercise for one league also create it for the other? Apparently, so. Also, can leagues with different genres use the same texts? Remember texts have genres assigned to them.

=cut

sub create : Local {
	my ($self, $c, $textId, $exerciseType, $exerciseId) = @_;
	my $text = $c->model('DB::Text')->find( { id=>$textId } );
	my $genre = $text->genre;
	$c->stash->{text} = $text;
	$c->stash->{genre} = $genre;
	$c->forward('clozecreate');
	$c->forward('questioncreate');
	$c->stash->{exercise_id} = $exerciseId;
	$c->stash->{template} = 'exercises/list.tt2';
}


=head2 delete

Delete an tournament.

=cut

sub delete : Local {
	my ($self, $c, $id) = @_;
	my $tournament = $c->model('DB::Tournaments')->find({id => $id})->
			delete_all;;
       $c->response->redirect($c->uri_for('list',
                   {status_msg => "Tournament deleted."}));
}


=head2 index 

=cut

sub index : Private {
    my ( $self, $c ) = @_;

    $c->response->body('Matched dic::Controller::Players in Players.');
}


=head1 AUTHOR

Dr Bean,,,

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
