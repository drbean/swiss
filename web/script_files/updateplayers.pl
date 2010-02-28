#!/usr/bin/perl

=head1 NAME

updateplayers.pl - Change players in database via script

=head1 SYNOPSIS

updateplayers.pl

=head1 DESCRIPTION

"Update missing players, eg transfers or without English names, not in original populate of Players, but now in league.yaml."

Do this in combination with update ratings, because ratings are not touched.

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

my $leagues = $script->league;
my %players;
for my $tournament ( qw/GL00012 MIA0009 BMA0077 BMA0076 FLA0031 GL00027 FLA0018/) {
	my $league = League->new( id =>
		"$config{leagues}/$tournament" );
	my $grades = Grades->new( league => $league );
	my $members = $league->members;
	foreach my $member ( @$members ) {
		my $id = $member->{id};
		unless ( defined $players{$id} ) { 
		$players{$id} = {
			name => $member->{name},
			id => $member->{id},
			};
		}
	}
}
my @players = values %players;
$players->update_or_create( $_ ) for @players;
