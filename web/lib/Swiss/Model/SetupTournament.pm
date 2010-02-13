package Swiss::Model::SetupTournament;

# Last Edit: 2010  2月 13, 12時06分49秒
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

Passing round a tournament, with players, is easier with the $c context.

=cut

sub build_per_context_instance {
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
			pairingnumber => $entrant->pairingNumber } );
	}
	return $tournament;
}


=head1 AUTHOR

A clever guy

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;

# vim: set ts=8 sts=4 sw=4 noet:
