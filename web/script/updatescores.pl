#!/usr/bin/perl

=head1 NAME

updatescores.pl -- Populate scores with tournament conversation points totals.

=head1 SYNOPSIS

perl updatescores.pl -l FLA0016

=head1 DESCRIPTION

Update or Populate scores tables using results of all rounds, or up to -r round, of -l tournament, from the Matches resultsource of the swiss database.Code taken from Compcomp (Standings)'s index method. TODO Transfer player

=head1 AUTHOR

Sebastian Riedel, C<sri@oook.de>

=head1 COPYRIGHT


This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";

use YAML qw/LoadFile/;
use List::MoreUtils qw/any/;

my @MyAppConf = glob( "/var/www/cgi-bin/swiss/swiss.yaml" );
die "Which of @MyAppConf is the configuration file?"
			unless @MyAppConf == 1;
my $config = LoadFile $MyAppConf[0];
my $name = $config->{name};
require $name . ".pm";
my $model = "${name}::Schema";
my $modelfile = "$name/Model/DB.pm";
my $modelmodule = "${name}::Model::DB";
# require $modelfile;

my $connect_info = $modelmodule->config->{connect_info};
my $d = $model->connect( @$connect_info );

use YAML qw/Dump/;
use IO::All;
use List::Util qw/sum/;

use Grades;

my $script = Grades::Script->new_with_options;
my $league = $script->league;
my $round = $script->round;
my $oldround = $script->one || $round;

( my $leagueid = $league ) =~ s/^([[:alpha:]]+[[:digit:]]+).*$/$1/;
my $leagueobject = League->new( leagues => $config->{leagues}, id => $leagueid );
my $tournament = Compcomp->new( league => $leagueobject );
my $members = $leagueobject->members;
my $matches = $d->resultset('Matches')->search({ tournament => $league });
my $conversations = defined $oldround? [ 1..$oldround ]:
										$tournament->all_events;
my $points;
my @Roles = qw/White Black/;
my @roles = map { lcfirst $_ } @Roles;
for my $round ( @$conversations ) {
	my @paired;
	my @matches = $matches->search({ round => $round })->all;
	MATCH: for my $match ( @matches ) {
		my %contestant = map { ucfirst($_) => $match->$_ } @roles;
		push @paired, values %contestant;
		my %opponent; @opponent{ 'White', 'Black' } =
			@contestant{ 'Black', 'White' };
		if ( $contestant{Black} eq 'Bye' ) {
			$points->{$round}->{ $contestant{White} } = 5;
			next MATCH;
		}
		my $forfeit = $match->forfeit;
		die "$forfeit forfeiters? Update " . @contestant{qw/White Black/} .
			"'s match in round $round." if
						$forfeit eq 'Unknown';
		unless ( $forfeit eq 'None' ) {
			my @forfeiters = $forfeit eq 'Both'? @Roles:
				( $forfeit );
			for ( @forfeiters ) {
				$points->{$round}->{ $contestant{$_} } = 0;
			}
		}
		my $tardy = $match->tardy;
		die "$tardy tardies? Update matches for $round round." if
						$tardy eq 'Unknown';
		unless ( $tardy eq 'None' ) {
			my @tardies = $tardy eq 'Both'? @Roles:
				( $tardy );
			for ( @tardies ) {
				$points->{$round}->{ $contestant{$_} } = 1;
			}
		}
		next MATCH if $forfeit eq ' Both' or $tardy eq 'Both';
		my $win = $match->win;
		die "$win winners? Update matches for $round round." if
						$win eq 'Unknown';
		unless ( $win eq 'None' ) {
			my $payout = $tournament->payout( values %contestant, $round );
				my %points = $win eq 'White'?
					( White => $payout->{win}, Black => $payout->{loss} ):
					$win eq 'Black'?
					( White => $payout->{loss}, Black => $payout->{win} ):
					$win eq 'Both'?
					( White => $payout->{draw}, Black => $payout->{draw} ):
					( White => '??', Black => '??' );
			for ( @Roles ) {
				$points->{$round}->{$contestant{$_}}=$points{$_}
					unless $forfeit eq $_ or $tardy eq $_;
			}
		}
	}
	my @unpaired = grep	{	my $id = $_->{id};
							not any { $_ eq $id } @paired
						} @$members;
	$points->{$round}->{$_} = 0 for map { $_->{id} } @unpaired;
}
my @scores;
for my $player ( @$members ) {
	my $id = $player->{id};
	my $score = sum map { $_->{$id} } @{$points}{@$conversations};
	push @scores, {
			tournament => $league,
			player => $id,
			value => $score || 0 };

}
my $t = $d->resultset('Scores');
$t->update_or_create( $_ ) for @scores;
print Dump { map { $_->{player} => $_->{value} } @scores };
