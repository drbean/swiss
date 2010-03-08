#!/usr/bin/perl

=head1 NAME

updateratings.pl - Enter new ratings of players in database via script

=head1 SYNOPSIS

updateratings.pl

=head1 DESCRIPTION

"Update ratings for missing players, eg transfers, not in original populate of Players, but now in league.yaml, for round 0 before rating changes."

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

my $script = Grades::Script->new_with_options;
my $tournament = $script->league;
my $round = $script->exercise;

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
my $ratings = $d->resultset('Ratings');

my $leagues = $script->league;
my @ratings;
my $league = League->new( id =>
	"$config{leagues}/$tournament" );
my $grades = Grades->new( league => $league );
my $members = $league->members;
foreach my $member ( @$members ) {
	my $id = $member->{id};
	push @ratings, 
		{ 
			player => $member->{id},
			tournament => $tournament,
			round => $round,
			value => $member->{rating} || 0 };
}
$ratings->update_or_create( $_ ) for @ratings;
