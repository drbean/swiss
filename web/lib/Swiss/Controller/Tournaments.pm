package Swiss::Controller::Tournaments;

# Last Edit: 2014 Jan 06, 09:00:41 AM
# $Id$

use Moose;
BEGIN { extends 'Catalyst::Controller'; }

use Grades;
use Grades::Groupwork;

use List::MoreUtils qw/none/;

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
    $c->stash->{tournament} = [$c->model('DB::Tournaments')->search(
	    { arbiter => $arbiterid })];
    # Set the TT template to use.  You will almost always want to do this
    # in your action methods (actions methods respond to user input in
    # your controllers).
    $c->stash->{template} = 'tournaments/list.tt2';
}


=head2 name

Tournament name. Add 'tournament' and 'tournaments' to session. Set 'tournament_round' session to 0 if new tournament. But remember, Not everyone agrees about what round it is.

=cut

sub name : Local {
        my ($self, $c) = @_;
	my $tourid = $c->request->params->{tourid};
	my $tourname = $c->request->params->{tourname};
	my $description = $c->request->params->{description};
	unless ( $tourid ) {
		$c->stash->{error_msg} = "What is the tournament's name & id?";
		$c->stash->{tourid} = $tourid;
		$c->stash->{tourname} = $tourname;
		$c->stash->{description} = $description;
		$c->stash->{template} = 'swiss.tt2';
		return;
	}
	my $arbiter = $c->session->{arbiter_id};
	my $tourneyset = $c->model('DB::Tournaments');
	my $candidate = $tourneyset->find({ id => $tourid });
	if ( $candidate and $candidate->arbiter ne $arbiter ) {
		$c->stash->{error_msg} =
"$tourid tournament id already in use by other arbiter. Choose a different id.";
		$c->stash->{tourid} = $tourid;
		$c->stash->{tourname} = $tourname;
		$c->stash->{description} = $description;
		$c->stash->{template} = 'swiss.tt2';
		return;
	}
	$c->stash->{tournament} = $tourid;
	$c->session->{tournament} = $tourid;
	$c->model('DB::Tournament')->update_or_create(
		{ id => $tourid, arbiter => $arbiter } );
	my $round;
	if ( my $resultset =
		$c->model('DB::Round')->find( { tournament => $tourid } ) ) {
		$round = $resultset->value;
	}
	else { $round = 0; }
	if ( not $candidate ) {
		$c->model('DB::Tournaments')->create( { id => $tourid,
			name => $tourname,
			description => $description,
			arbiter => $arbiter,
			round => [ { tournament => $tourid,
					round => $round } ]
				} );
		$c->session->{"${tourid}_round"} = $round;
		$c->stash->{round} = $round + 1;
		$c->stash->{template} = 'players.tt2';
		return;
	}
	else {
		$c->detach( 'edit_players' );
	}
}


=head2 add_player

First round, players. IDs, names and ratings are limited to 10, 20 and 4 characters, respectively.

=cut

sub add_player : Local {
        my ($self, $c) = @_;
	my $tourid = $c->session->{tournament};
	my $tourney = $c->model('DB::Tournaments')->find({ id=>$tourid });
	my $round = $c->model('DB::Round')->find( { tournament => $tourid } )
			->value;
	my $memberSet = $c->model('DB::Members')->search(
		{ tournament => $tourid });
	my @playerlist;
	while ( my $member = $memberSet->next )
	{
		my $profile = $member->profile;
		my $rating = $member->profile->rating->find({
				tournament => $tourid, round => $round })->value;
		push @playerlist, { id => $profile->id,
			name => $profile->name, rating => $rating };
	}
	$c->stash->{tournament} = $tourid;
	my %entrant = map { $_ => $c->request->params->{$_} } qw/id name rating/;
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
		my %entrantentry = %entrant;
		$entrantentry{rating} = [ {
				player => $entrant{id}, tournament => $tourid,
				round => $round, value => $entrant{rating} } ];
		my $playerSet = $c->model('DB::Players');
		$playerSet->create( \%entrantentry );
		$memberSet->create({ player => $entrant{id}, tournament => $tourid,
				absent => 'False', firstround => ($round+1) });
	}
	$c->stash->{round} = $round+1;
	$c->stash->{template} = 'players.tt2';
}


=head2 edit_players

Later rounds, players

=cut

sub edit_players : Local {
        my ($self, $c) = @_;
	my $tourid = $c->session->{tournament};
	my $tourney = $c->model('DB::Tournaments')->find({ id=>$tourid });
	my $round = $c->model('DB::Round')->find( { tournament => $tourid } )
			->value;
	my $newlist = $c->request->params->{playerlist};
	my @playerlist;
	@playerlist = $c->model('GTS')->parsePlayers( $tourid, $newlist)
		if $newlist;
	if ( not $newlist ) {
		my $memberSet = $tourney->members;
		while ( my $member = $memberSet->next )
		{
			my $profile = $member->profile;
			my $rating = $member->profile->rating->find({
				tournament => $tourid, round => $round });
			my $value; $value = $rating->value if $rating;
			push @playerlist, { id => $profile->id, name => $profile->name,
					firstround => $member->firstround, rating => $value
				};
		}
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
		my $playerSet = $c->model('DB::Players');
		my $memberSet = $c->model('DB::Members');
		my $ratingSet = $c->model('DB::Ratings');
		for my $player ( @playerlist ) {
			my $firstround = defined $player->{firstround}?
						$player->{firstround}: $round + 1;
			$ratingSet->update_or_create({ player => $player->{id},
					tournament => $tourid, round => $round,
					value => $player->{rating} });
			my $entry = { id => $player->{id}, name => $player->{name} };
			$playerSet->update_or_create( $entry );
			$memberSet->update_or_create({ player => $player->{id},
					tournament => $tourid, absent => 'False',
					firstround => $firstround });
		}
		$c->stash->{playerlist} = \@playerlist;
	}
	$c->stash->{round} = $round+1;
	$c->stash->{template} = 'players.tt2';
}


=head2 final_players

Finish editing players

=cut

sub final_players : Local {
        my ($self, $c) = @_;
	my $tourid = $c->session->{tournament};
	my $round = $c->model('DB::Round')->find( { tournament => $tourid } )
			->value;
	my @players = $c->model('DB::Members')->search(
		{ tournament => $tourid });
	my $tournament = $c->model('DB::Tournaments')->find({
		id => $tourid });
	$c->stash->{selected} = $tournament->rounds if $tournament;
	my $playerNumber = @players % 2? @players: $#players;
	$c->stash->{tournament} = $tourid;
	$c->stash->{rounds} = $playerNumber;
	$c->stash->{round} = $round;
	$c->stash->{template} = 'rounds.tt2';
}


=head2 rounds

Number of rounds

=cut

sub rounds : Local {
        my ($self, $c) = @_;
	my $tourid = $c->session->{tournament};
	( my $leagueid = $tourid ) =~ s/^([[:alpha:]]+[[:digit:]]+).*$/$1/;
	my $round = $c->model('DB::Round')->find( { tournament => $tourid } )
			->value;
	my $league = League->new( leagues => $c->config->{leagues},
					id => $leagueid );
	my $grades = Groupwork->new( league => $league );
	my $series = $grades->beancanseries;
	my $session = ( sort {$a <=> $b} keys %$series )[-1];
	my $beancans = $grades->beancan_names( $session );
	my $members = $c->model('DB::Members')->search(
		{ tournament => $tourid });
	my (@players, %seen);
	for my $can ( sort keys %$beancans ) {
		my $group = $beancans->{$can};
		for my $player ( @$group ) {
			next if not defined $player;
			my $id = $league->ided( $player );
			my $member = $members->find({ player => $id });
			push @players, { id => $id, name => $member->profile->name,
				absent => $member->absent };
			$seen{$id}++;
		}
		push @players, { id => undef, name => undef, absent => undef };
	}
	while ( my $member = $members->next ) {
		my $id = $member->player;
		push @players, { id => $id, name => $member->profile->name,
			absent => $member->absent } unless $seen{$id};
	}
	my $rounds = $c->request->params->{rounds};
	$c->model('DB::Tournaments')->find( { id => $tourid } )
				->update( { rounds => $rounds } );
	$c->stash->{tournament} = $tourid;
	$c->stash->{round} = $round + 1;
	$c->stash->{playerlist} = \@players;
	$c->stash->{template} = 'absentees.tt2';
}


=head2 absentees

Withdrawn, absent players who will not be paired.

=cut

sub absentees : Local {
        my ($self, $c) = @_;
	my $tourid = $c->session->{tournament};
	my $round = $c->model('DB::Round')->find( { tournament => $tourid } )
			->value;
	my $members = $c->model('DB::Members')->search(
		{ tournament => $tourid });
	while ( my $member = $members->next ) {
		my $absence = $c->request->params->{ $member->profile->id };
		if ( $absence ) { $member->update( { absent => 'True' } ) }
		else { $member->update( { absent => 'False' } ) }
	}
	$c->stash->{tournament} = $tourid;
	$c->stash->{round} = $round + 1;
	# $c->stash->{playerlist} = \@playerlist;
	$c->stash->{template} = 'preppair.tt2';
}


=head2 delete

Delete an tournament.

=cut

sub delete : Local {
	my ($self, $c, $id) = @_;
	my $tournament = $c->model('DB::Tournaments')->find({id => $id})->
			delete;
       $c->response->redirect($c->uri_for('/swiss',
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
