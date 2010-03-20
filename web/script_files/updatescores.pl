#!/usr/bin/perl

=head1 NAME

loadYAML.pl -- Populate scores with tournament conversation points totals.

=head1 SYNOPSIS

web/script_files/scores.pl -l FLA0016

=head1 DESCRIPTION

Update or Populate scores tables using points.yaml files of all conversations of -l tournament, from the 'points.yaml' files below the appropriate directory, as recorded in the 'compcomp' field of 'league.yaml'.

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

my $leagueobject = League->new( leagues => $config{leagues}, id => $league );
my $tournament = Grades->new( league => $leagueobject );
my $members = $leagueobject->members;
my $conversations = $tournament->conversations;
my ($points, @scores);
for my $conversation ( @$conversations ) {
	$points->{$conversation} = $tournament->points($conversation);
}
for my $player ( @$members ) {
	my $id = $player->{id};
	my $score = sum map { $_->{$id} } @{$points}{@$conversations};
	push @scores, {
			tournament => $league,
			player => $id,
			score => $score || 0 };

}
my $t = $d->resultset('Scores');
$t->update_or_create( $_ ) for @scores;
