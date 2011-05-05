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

my $s = $d->resultset('Arbiters');

my @officials = ( [ qw/id name password/ ] );
push @officials, [split] for <<OFFICIALS =~ m/^.*$/gm;
193001	DrBean	ok
greg	greg	ok
OFFICIALS
$s->populate( \@officials );

$s = $d->resultset('Tournaments');

my (@newtournaments, @firstrounds);
for my $tournament ( qw/FIA0038 BMA0033 FLA0016 FLA0030 MIA0012 FLA0021 GL00022 GL00005/ ) {
	( my $id = $tournament ) = s/^(\w*).*$/$1/;
	my $league = League->new( leagues =>
		$config{leagues}, id => $id );
	my $members = $league->members;
	# @$members = grep { $_->{name} =~ m/^[0-9a-zA-Z'-]*$/ } @$members;
	my @members = map { {
		tournament => $tournament, player => $_->{id}, absent => 'False',
		firstround => 1 } }
		@$members;
	my $grades = Grades->new({ league => $league });
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
		members => \@members,
		};
	my $firstround = { value => 0, tournament => $tournament };
	push @newtournaments, $newtournament;
	push @firstrounds, $firstround;
}
$s->populate( \@newtournaments );
$s->populate( \@firstrounds );

sub uptodatepopulate {
	my $class = $d->resultset(shift);
	my $entries = shift;
	my $columns = shift @$entries;
	foreach my $row ( @$entries )
	{  
	    my %hash;
	    @hash{@$columns} = @$row;
	    $class->update_or_create(\%hash);
	}
}

