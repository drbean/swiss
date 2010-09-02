package Swiss::Model::SetupTournament;

# Last Edit: 2010  9月 01, 15時21分22秒
# $Id$

use strict;
use warnings;

use List::MoreUtils qw/any all notall/;

=head1 NAME

Swiss::Model::SetupTournament - With controller context

=head1 DESCRIPTION

Moose role Catalyst::Component::InstancePerContext allows passing of Catalyst controller context.

=cut

use Moose;
with 'Catalyst::Component::InstancePerContext';

require Games::Tournament::Swiss;
require Games::Tournament::Contestant::Swiss;

=head2 setupTournament

Passing round a tournament, with 'entrants' and 'absentees' args, is easier with the $c context. Context is used to store pairing numbers.

=cut

sub setupTournament {
	my ($self, $c, $args) = @_;
	my $entrants = $args->{entrants};
	my $absentees = $args->{absentees};
	my (@entrants, @absentees);
	delete $args->{$absentees};
	my @absentids = map { $_->{id} } @$absentees;
	for my $profile ( @$entrants ) {
		my $entrant = Games::Tournament::Contestant::Swiss->new(
			%$profile );
		push @entrants, $entrant;
		push @absentees, $entrant if 
			any { $_ eq $entrant->id } @absentids;
	}
	@$entrants = @entrants; @$absentees = @absentees;
	my $tournament = Games::Tournament::Swiss->new( %$args );
	$tournament->assignPairingNumbers;
	$entrants = $tournament->entrants;
	for my $entrant ( @$entrants ) {
		$c->model('DB::Pairingnumbers')->update_or_create( { 
			 tournament => $args->{name}, player => $entrant->id,
			value => $entrant->pairingNumber } );
	}
	return $tournament;
}


=head2 build_per_context_instance

The method that $c->component( 'SetupTournament', $args ) will call.

=cut

sub build_per_context_instance {
	my ($self, $c, $args) = @_;
	return $self->setupTournament( $c, $args );
}


=head1 AUTHOR

A clever guy

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;

# vim: set ts=8 sts=4 sw=4 noet:
