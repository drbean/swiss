#!/usr/bin/perl

=head1 NAME

updateplayers.pl - Change players in database via script

=head1 SYNOPSIS

updateplayers.pl

=head1 DESCRIPTION

"Update missing players, eg transfers or without English names, not in original populate of Players, but now in league.yaml." Update ratings for players also but just in round 0, ie before the tournament starts. 


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
my $players = $d->resultset('Players');
my $ratings = $d->resultset('Ratings');
my %players;
my @ratings;
my $leagues = $script->league;
for my $tournament ( qw/GL00012 MIA0009 BMA0077 BMA0076 FLA0031 GL00027 FLA0018/) {
	my $league = League->new( id =>
		"$config{leagues}/$tournament" );
	my $members = $league->members;
	foreach my $member ( @$members ) {
		my $id = $member->{id};
		unless ( defined $players{$id} ) { 
		$players{$id} = {
			name => $member->{name},
			id => $member->{id},
			};
		push @ratings, 
			{ 
				player => $member->{id},
				tournament => $tournament,
				round => 0,
				value => $member->{rating} || 0 };
		}
	}
}
my @players = values %players;
$players->update_or_create( $_ ) for @players;
$ratings->update_or_create( $_ ) for @ratings;
