#!/usr/bin/perl

=head1 NAME

populateplayers.pl - Enter players in database via script

=head1 SYNOPSIS

populateplayers.pl

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
my $s = $d->resultset('Players');

my $leagues = $script->league;
for my $tournament ( "GL00029", "beans/t/emile" ) {
	my $league = League->new( id =>
		"$config{leagues}/$tournament" );
	my $grades = Grades->new( league => $league );
	my $members = $league->members;
	my $comps = $grades->conversations;
	my @newmembers = map {
		{
			name => $_->{name},
			id => $_->{id},
			rating => $_->{rating} || 0,
			firstrounds => { 
				tournament => $tournament,
				player => $_->{id},
				firstround => 1, }
		}
			} @$members;
	$s->populate( \@newmembers );
}
