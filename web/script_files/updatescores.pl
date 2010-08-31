#!/usr/bin/perl

=head1 NAME

loadYAML.pl -- Populate scores with tournament conversation points totals.

=head1 SYNOPSIS

web/script_files/scores.pl -l FLA0016

=head1 DESCRIPTION

Update or Populate scores tables using results of all rounds of -l tournament, from the 'result.yaml' files below the appropriate directory, as recorded in the 'compcomp' field of 'league.yaml'. Code taken from Grades (CompComp)'s points method. TODO Transfer player

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
my $league = $script->league;
my $round = $script->round;

my $leagueobject = League->new( leagues => $config{leagues}, id => $league );
my $tournament = CompComp->new( league => $leagueobject );
my $members = $leagueobject->members;
my $conversations = defined $round? [ 1..$round ]: $tournament->all_weeks;
my ($points, @scores);
for my $round ( @$conversations ) {
	my $config = $tournament->config( $round );
	my $forfeits = $config->{forfeit};
	my $tardies = $config->{tardy};
	my $unpaired = $config->{unpaired};
	my $scores = $tournament->scores($round);
	GROUP: for my $group ( keys %$scores ) {
		my $myscore = $scores->{$group};
		my @ids = keys %$myscore;
		my %theirscore;
		@theirscore{ @ids } = @$myscore{ reverse @ids };
		ID: for my $id ( @ids ) {
			if ( $id eq 'Bye' or $myscore->{$id} eq 'Bye' ) {
				$points->{$round}->{$myscore->{$id}}=5;
				$points->{$round}->{$id}=5;
				next GROUP;
			}
			if ( any { $_ eq $id } @$tardies ) {
				$points->{$round}->{$id} = 1;
				next ID;
			}
			if ( any { $_ eq $id } @$unpaired, @$forfeits ) {
				$points->{$round}->{$id} = 0;
				next ID;
			}
			# TODO Transfer player
			$points->{$round}->{$id} =
				( $myscore->{$id} > $theirscore{$id} )?
				 5: ( $myscore->{$id} < $theirscore{$id} )?
				 3: ( $myscore->{$id} == $theirscore{$id} )?
				 4: "???";
		}
	}
}
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
