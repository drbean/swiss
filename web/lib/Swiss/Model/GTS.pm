package Swiss::Model::GTS;

# Last Edit: 2009  8月 05, 21時54分44秒
# $Id$

use strict;
use warnings;
use parent 'Catalyst::Model';

use CGI::Simple::Util qw/escape unescape/;
use List::MoreUtils qw/notall/;

=head1 NAME

Swiss::Model::GTS - Games::Tournament::Swiss Catalyst Swiss App Model backend

=head1 DESCRIPTION

Catalyst Model.

=cut

use Games::Tournament::Swiss::Config;

my $swiss = Games::Tournament::Swiss::Config->new;

my $roles = [qw/White Black/];
my $scores = { win => 1, loss => 0, draw => 0.5, forfeit => 0, bye => 1 };
my $firstround = 1;
my $algorithm = 'Games::Tournament::Swiss::Procedure::FIDE';
my $abbrev = { W => 'White', B => 'Black', 1 => 'Win', 0 => 'Loss',
	0.5 => 'Draw', '=' => 'Draw'  };

$swiss->frisk($scores, $roles, $firstround, $algorithm, $abbrev);

$Games::Tournament::Swiss::Config::firstround = $firstround;
%Games::Tournament::Swiss::Config::scores = %$scores;
@Games::Tournament::Swiss::Config::roles = @$roles;
$Games::Tournament::Swiss::Config::algorithm = $algorithm;

require Games::Tournament::Swiss;
require Games::Tournament::Contestant::Swiss;

=head2 roles

Roles

=cut

sub roles { return \@Games::Tournament::Swiss::Config::roles; }


=head2 turnIntoCookies

Prepare cookies for a tournament's players with ids, names, ratings, and perhaps later, preference histories, float histories, and scores. The cookie name for the player ids is 'tournament_ids' (where 'tournament' is the name of the tournament) and the values are a list of the players ids. The tournament name is to distinguish different tournaments being paired from the same browser.

=cut

sub turnIntoCookies {
	my ($self, $tournament, $playerlist) = @_;
	my %cookie;
	for my $key ( qw/id name rating/ ) {
		my @keylist = map { $_->{$key} } @$playerlist;
		my $keystring = join "&", map { escape( $_ ) } @keylist;
		$cookie{$tournament . '_' . $key . 's'} = $keystring;
	}
	return %cookie;
}


=head2 turnIntoPlayers

Inflate a tournament's players' cookies with ids, names, ratings, and perhaps later, preference histories, float histories, and scores and return as an array of hashes for each individual player.

=cut

sub turnIntoPlayers {
	my ($self, $tourney, $cookies) = @_;
	my @playerlist;
	my @cookieNames = map { "${tourney}_${_}s" } qw/id name rating/;
	for my $name ( @cookieNames ) {
		next unless exists $cookies->{$name};
		my $playercookie = $cookies->{$name};
		next unless $playercookie and
				$playercookie->isa('CGI::Simple::Cookie');
		(my $fieldname = $name ) =~ s/^${tourney}_(.*)s$/$1/;
		my $playerstring = $playercookie->value;
		my @values = map { unescape( $_ ) } split /[&;]/, $playerstring;
		for my $n ( 0 .. @values-1 ) {
			$playerlist[$n]->{$fieldname} = $values[$n];
		}
	}
	return @playerlist;
}


=head2 parsePlayers

Parse the line of ids, names and ratings into a list of hashes.

=cut

sub parsePlayers {
	my ($self, $tourney, $records) = @_;
	my @playerlist;
	my @records = split /\n/, $records;
	for my $line ( @records ) {
		next if $line =~ m/^$/;
		my %player;
		chomp $line;
		my @fields = split ' ', $line;
		my $n;
		if ( $n = @fields and $n > 3 ) {
			my $name = join ' ', @fields[1..$n-2];
			splice @fields, 1, $n-2, $name;
		}
		@player{qw/id name rating/} = @fields;
		$player{id} = substr $player{id}, 0, 7;
		$player{name} = substr $player{name}, 0, 20;
		$player{rating} = substr $player{rating}, 0, 4;
		push @playerlist, \%player;
	}
	return @playerlist;
}


=head2 pair

Pair players for the next round of a swiss tournament

=cut

sub pair {
	my ($self, $args) = @_;
	my $rounds = $args->{rounds};
	my $playerlist = $args->{entrants};
	my @entrants = map { Games::Tournament::Contestant::Swiss->new(
				%$_ ) } @$playerlist;
	my $tourney = Games::Tournament::Swiss->new(
		round => 0,
		rounds => $rounds,
		entrants => \@entrants );
	$tourney->idNameCheck;
	# $tourney->loggedProcedures('ASSIGNPAIRINGNUMBERS');
	$tourney->assignPairingNumbers;
	$tourney->initializePreferences;
	# io('=')->print($tourney->catLog('ASSIGNPAIRINGNUMBERS'));
	my %brackets = $tourney->formBrackets;
	my $pairing = $tourney->pairing( \%brackets );
	# $pairing->loggingAll;
	my $results = $pairing->matchPlayers;
	my $matches = $results->{matches};
	my @games;
	my %number = map { $_ => $brackets{$_}->number } keys %brackets;
	for my $bracket ( sort { $number{$a} cmp $number{$b} } keys %$matches )
	{
	    my $bracketmatches = $matches->{$bracket};
	    push @games, grep { ref eq 'Games::Tournament::Card' }
		@$bracketmatches;
	}
	$tourney->round(1);
	my @tables = $tourney->publishCards(@games);
}


=head2 allFieldCheck

Does the same thing as idCheck in Games::Tournament but returns an error message instead of dying.

=cut

sub allFieldCheck {
	my ($self, @playerlist) = @_;
	my $message;
	for my $player ( @playerlist ) {
		if ( notall { $player->{$_} } qw/id name rating/ ) {
			$message ||=
			"Each entrant must have an id, name and rating. ";
			$message .=
"Player $player->{name}, id: $player->{id}, missing id, name or rating. ";
		}
	}
	return $message;
}


=head2 idDupe

Does the same thing as idCheck in Games::Tournament but returns an error message instead of dying.

=cut

sub idDupe {
	my ($self, @playerlist) = @_;
	my %idcheck;
	for my $player ( @playerlist ) {
		my $id = $player->{id};
		my $name = $player->{name};
		if ( defined $idcheck{$id} ) {
		    return $name . " and $idcheck{$id} have the same id: $id";
	}
	$idcheck{$id} = $name;
	}
	return;
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
