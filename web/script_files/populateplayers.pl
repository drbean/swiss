#!/usr/bin/perl

=head1 NAME

populateplayers.pl - Enter players in database via script

=head1 SYNOPSIS

populateplayers.pl

=head1 DESCRIPTION

Enter players in database via script. TODO Include the nonentity, Bye player, who makes a pair when there are an odd number of players. Problem is how to prevent a partner being looked for for that Bye player.

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
my $p = $d->resultset('Players');

my $leagues = $script->league;
my %players;
for my $tournament ( qw/GL00013 CLA0023 GL00006 MIA0014 FLA0030 BMA0071 FLA0014 FLA0017/ ) {
	my $league = League->new( leagues => 
		$config{leagues}, id => $tournament );
	my $grades = Grades->new({ league => $league });
	my $members = $league->members;
	foreach my $member ( @$members ) {
		my $id = $member->{id};
		unless ( defined $players{$id} ) { 
		$players{$id} = {
			name => $member->{name},
			id => $member->{id},
			rating => [ { 
				player => $member->{id},
				tournament => $tournament,
				round => 0,
				value => $member->{rating} || 0 } ]
			};
		}
		else {
			push @{ $players{$id}->{rating} }, 
				{ 
					player => $member->{id},
					tournament => $tournament,
					round => 0,
					value => $member->{rating} || 0 };
		}
	}
}
my @players = values %players;
$p->populate( \@players );
