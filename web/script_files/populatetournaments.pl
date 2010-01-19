#!/usr/bin/perl
#!/usr/bin/perl

=head1 NAME

populateplayers.pl - Enter players in database via script

=head1 SYNOPSIS

populate.players.pl

=head1 DESCRIPTION

Enter players in database via script

=head1 AUTHOR

Dr Bean

=head1 COPYRIGHT


This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/../lib";

use IO::All;
my $io = io '-';

use Grades;

use Config::General;

my @MyAppConf = glob( "$Bin/../*.conf" );
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
my $s = $d->resultset('Tournaments');

my @newtournaments;
for my $tournament ( qw/GL00029 GL00030 GL00031 FLA0016/ ) {
	my $league = League->new( id =>
		"/home/drbean/class/$tournament" );
	my $members = $league->members;
	my @members = map { { tournament => $tournament, player => $_->{id}, absent => 'False' } } @$members;
	my $grades = Grades->new( league => $league );
	my $id = $league->id;
	my $name = $league->name;
	my $description = $league->field;
	my $arbiter = '193001';
	my $rounds = 6;
	my $newtournament = {
		name => $name,
		id => $tournament,
		description => $description,
		arbiter => $arbiter,
		rounds => 6,
		round => { round => 0, tournament => $id },
		members => \@members,
		};
	push @newtournaments, $newtournament;
}
$s->populate( \@newtournaments );


