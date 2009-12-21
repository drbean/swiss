package Swiss::Model::SetupTournament;

# Last Edit: 2009 10月 14, 12時09分11秒
# $Id$

use strict;
use warnings;

use CGI::Simple::Util qw/escape unescape/;
use List::MoreUtils qw/any all notall/;

=head1 NAME

Swiss::Model::GTS - Games::Tournament::Swiss Catalyst Swiss App Model backend

=head1 DESCRIPTION

Catalyst Model.

=cut

use Moose;
with 'Catalyst::Component::InstancePerContext';

require Games::Tournament::Swiss;
require Games::Tournament::Contestant::Swiss;

=head2 setupTournament

Passing round a tournament, with players, is easier.

=cut

sub build_per_context_instance {
	my ($self, $c, $args) = @_;
	my $entrants = $args->{entrants};
	my $absentees = $args->{absentees};
	my (@entrants, @absentees);
	delete $args->{$absentees};
	my @absentids = map { $_->{id} } @$absentees;
	for my $entrant ( @$entrants ) {
		push @entrants,
			Games::Tournament::Contestant::Swiss->new( %$entrant );
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


__END__

=head1 SYNOPSIS

pair

=head1 OPTIONS

=over 8

=item B<--man> A man page

=item B<--help> This help message

=back

=head1 DESCRIPTION

=over 8

=item B<SCRIPTS>

The scripts in script_files/ need to be installed somewhere so that they can be run in the directory in which pairing of each round is done.

=item B<DIRECTORY LAYOUT>

The scripts assume that there is a directory in which a configuration file, called league.yaml, with data about the players exists. The rounds are paired in subdirectories, named 1,2,3,.. in this directory. A file called pairtable.yaml in the subdirectory allows pairing of the round to take place. This file can be created from a pairing table, eg pairing.txt, by running B<pairtable2yaml pairing.txt>

=item B<DATA FILES>

Do B<NOT> use tabs in these YAML files. The level of indentation is significant. Follow the examples closely. The first, league.yaml has lines of the form:

member:
  - id: 1
    name: Laver, Rod
    rating: 2810
    title: Grandmaster
  - id: 2
    name: Sampras, Pete
    rating: 2800
    title: Unknown
  - id: 3
    name: McEnroe, John
    rating: 2780
    title: Unknown

Late entries are separate.

If you are using your own scoring scheme, and colors (called, roles), see the example in t/tennis in the distribution. You can add your own data to the member and late records. A pairing number is generated for the players, so don't include a pairing number. The new id (ie pairing number) is added to league.yaml. This is a bit tricky. I am working with names here (eg with the absentees and the pairings left in round.yaml). TODO Configuration of your own scoring scheme looks like it is broken.

B<pairtable.yaml> is of the form:

---
opponents:
 1 : [6,4,2,5]
 2 : [7,3,1,4]
 6 : [1,5,3,9]
roles:
 1 : [White,Black,White,Black]
 2 : [White,Black,White,Black]
 6 : [White,Black,White,Black]
floats:
 1 : [Up,Down]
 2 : [~,Down]
 6 : [~,~]
score:
 1: 3.5
 2: 3.5
 6: 2.5

Or its equivalent. As for league.yaml, indentation (no tabs) is important.

=item B<GENERATING PAIRINGS>

Starting with an empty main directory, create league.yaml, and an empty subdirectory for the first round. Run the script, 'pair' in the empty round subdirectory. A log of the pairing is printed and 'round.yaml' in the directory contains the matches. A number of other yaml files are created to store state for the round. (These will probably go away in a later version of this script).

After the games in the round are complete, create a pairing table for the next round. (Perhaps you can use B<pairingtable>. This currently uses the yaml serialization files in the round subdirectory and score files in the scores subdirectory. Enter the scores for the players in the file, '1.yaml', or whatever the round is. A template file is generated in the round subdirectory. Then you can run 'crosstable' or 'pairingtable' in the original directory above the subdirectory, to get current standings.) If there is a next round, make another empty subdirectory named after it, put pairtable.yaml (created by hand or by B<pairtable2yaml>) in it and continue as before. You add late-entering players in league.yaml in the main directory.

=back

=cut

# vim: set ts=8 sts=4 sw=4 noet:
=head1 AUTHOR

A clever guy

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
