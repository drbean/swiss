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
my $s = $d->resultset('Players');

for my $tournament ( qw/GL00029 GL00030 GL00031 FLA0016/ ) {
	my $league = League->new( id =>
		"/home/drbean/class/$tournament" );
	my $grades = Grades->new( league => $league );
	my $members = $league->members;
	my $comps = $grades->conversations;
	my @newmembers;
	for my $member ( @$members ) {
		my $name = $member->{name};
		next unless $name =~ m/^[0-9a-zA-Z'-]*$/;
		my $id = $member->{id};
		my $rating = 0;
		for my $comp ( @$comps ) {
			no warnings 'uninitialized';
			$rating += $grades->points( $comp )->{$id};
			use warnings 'uninitialized';
		}
		$member->{newrating} = $rating;
		push @newmembers, {
			name => $name,
			id => $id,
			rating => $rating,
			firstrounds => { 
				tournament => $tournament,
				player => $id,
				firstround => 1, }
		};
	}
	@newmembers = sort { $b->{newrating} <=> $a->{newrating} } @newmembers;
	# $io->print( "$_->{id}\t$_->{name}\t$_->{newrating}\t1\n") for @newmembers;
	$s->populate( \@newmembers );
}


