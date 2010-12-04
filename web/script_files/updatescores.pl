#!/usr/bin/perl

=head1 NAME

loadYAML.pl -- Populate scores with tournament conversation points totals.

=head1 SYNOPSIS

web/script_files/scores.pl -l FLA0016

=head1 DESCRIPTION

Update or Populate scores tables using results of all rounds, or up to -r round, of -l tournament, from the Matches resultsource of the swiss database.Code taken from CompComp (Standings)'s index method. TODO Transfer player

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

use Config::General;
use List::MoreUtils qw/any/;

my @MyAppConf = glob( "$FindBin::Bin/../*.conf" );
die "Which of @MyAppConf is the configuration file?"
			unless @MyAppConf == 1;
my %config = Config::General->new($MyAppConf[0])->getall;
my $name = $config{name};
require $name . ".pm";
my $model = "${name}::Schema";
my $modelfile = "$name/Model/DB.pm";
my $modelmodule = "${name}::Model::DB";
# require $modelfile;

my $connect_info = $modelmodule->config->{connect_info};
my $d = $model->connect( @$connect_info );

use YAML qw/LoadFile DumpFile/;
use IO::All;
use List::Util qw/sum/;

use Grades;

my $script = Grades::Script->new_with_options;
my $leagueid = $script->league;
my $round = $script->round;

my $leagueobject = League->new( leagues => $config{leagues}, id => $league );
my $tournament = CompComp->new( league => $leagueobject );
my $members = $leagueobject->members;
my $matches = $d->resultset('Matches')->search({ tournament => $league });
my $conversations = defined $round? [ 1..$round ]: $tournament->all_weeks;
my ($points);
my @Roles = qw/White Black/;
my @roles = map { lcfirst $_ } @Roles;
for my $round ( @$conversations ) {
	my @matches = $matches->search({ round => $round })->all;
	MATCH: for my $match ( @matches ) {
		my %contestant = map { ucfirst($_) => $match->$_ } @roles;
		my %opponent; @opponent{ 'White', 'Black' } =
			@contestant{ 'Black', 'White' };
		if ( $contestant{Black} eq 'Bye' ) {
			$points->{$round}->{ $contestant{White} } = 5;
			next MATCH;
		}
		my $forfeit = $match->forfeit;
		die "$forfeit forfeiters? Update matches for $round round." if
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
			my %points = $win eq 'White'?
				( White => 5, Black => 3 ):
				$win eq 'Black'?
				( White => 3, Black => 5 ):
				$win eq 'Both'?
				( White => 4, Black => 4 ):
				( White => '??', Black => '??' );
			for ( @Roles ) {
				$points->{$round}->{$contestant{$_}}=$points{$_}
					unless $forfeit eq $_ or $tardy eq $_;
			}
		}
	}
}
my @scores;
for my $player ( @$members ) {
	my $id = $player->{id};
	my $score = sum map { $_->{$id} } @{$points}{@$conversations};
	push @scores, {
			tournament => $leagueid,
			player => $id,
			value => $score || 0 };

}
my $t = $d->resultset('Scores');
$t->update_or_create( $_ ) for @scores;
