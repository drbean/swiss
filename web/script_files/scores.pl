#!/usr/bin/perl

=head1 NAME

loadYAML.pl -- Populate scores with tournament conversation points totals.

=head1 SYNOPSIS

web/script_files/scores.pl FLA0016

=head1 DESCRIPTION

Populate scores tables using points.yaml files of all conversations of ARGV[0] tournament, from the 'points.yaml' file of the appropriate directory, as recorded in the 'conversations' sequence of 'league.yaml'. If scores exist will not update them. You will have to delete those rows.

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

my $league = $ARGV[0];

my $leaguedata = LoadFile "/home/drbean/class/$league/league.yaml";
my $members = $leaguedata->{member};
# my $conversations = $leaguedata->{conversations};
my $conversations = [ 1..2 ];
my ($points, @scores);
for my $conversation ( @$conversations ) {
	$points->{$conversation} = LoadFile
		"/home/drbean/class/$league/comp/$conversation/points.yaml";
}
push @scores, [qw/tournament player score/];
for my $player ( @$members ) {
	my $id = $player->{id};
	my $score = sum map { $_->{$id} } @{$points}{@$conversations};
	push @scores, [ $league, $id, $score ];

}
my $t = $d->resultset('Scores');
$t->populate(\@scores);
