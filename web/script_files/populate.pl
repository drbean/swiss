#!/usr/bin/perl

=head1 NAME

populateplayers.pl - Enter players in database via script

=head1 SYNOPSIS

populateplayers.pl

=head1 DESCRIPTION

Enter players, tournaments in database via script. TODO Include the nonentity, Bye player, who makes a pair when there are an odd number of players. Problem is how to prevent a partner being looked for for that Bye player.

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
use Try::Tiny;

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

my @officials;
push @officials, { id => '193001', name => 'DrBean', password => 'ok' };
find_or_populate( 'Arbiters', \@officials );

my $roundset = $d->resultset('Round');
my (@startingrounds, %players, @members, @scores);
for my $tournament ( qw/FIA0038 BMA0033 BMA0033-1 FLA0016 FLA0016-1 FLA0030 MIA0012 FLA0021 GL00022 GL00005/ ) {
( my $id = $tournament ) =~ s/^([[:alpha:]]+[[:digit:]]+).*$/$1/;
	my $league = League->new( leagues => $config{leagues}, id => $id );
	my $members = $league->members;
	my $grade = Grades->new({ league => $league })->grades;
	my $name = $league->name;
	my $description = $league->field;
	my $arbiter = '193001';
	my $rounds = 18;
	my $firstround = { value => 0, tournament => $tournament };
	$d->resultset('Tournaments')->find_or_create( {
			name => $name,
			id => $tournament,
			description => $description,
			arbiter => $arbiter,
			rounds => $rounds,
		} );
	my $round = $roundset->find({ tournament => $tournament });
	$round = $round? $round->value: 0;
	push @startingrounds, { tournament => $tournament, value => $round };
	foreach my $member ( @$members ) {
		my $id = $member->{id};
		push @members, { player => $id, tournament => $tournament,
							absent => 'False', firstround => $round };
		push @scores, { tournament => $tournament, player => $id };
		unless ( defined $players{$id} ) { 
			$players{$id} = {
				name => $member->{name},
				id => $id,
				rating => [ { 
					player => $member->{id},
					tournament => $tournament,
					round => 0,
					value => $grade->{$id} || $member->{rating} || 0 } ]
			};
		}
		else {
			push @{ $players{$id}->{rating} }, 
				{ 
					player => $member->{id},
					tournament => $tournament,
					round => 0,
					value => $grade->{$id} || $member->{rating} || 0 };
		}
	}
}
my @players = values %players;
find_or_populate( 'Players', \@players );
find_or_populate( 'Round', \@startingrounds );
find_or_populate( 'Members', \@members );
find_or_populate( 'Scores', \@scores );

sub find_or_populate
{
    my $class = $d->resultset(shift);
    my $entries = shift;
    foreach my $entry ( @$entries ) {
		try { $class->find_or_create( $entry ); }
			catch { warn "$_ in " .  $class->result_source->source_name };
	}
}

