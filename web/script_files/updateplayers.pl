#!/usr/bin/perl

=head1 NAME

updateplayers.pl - Change players in database via script

=head1 SYNOPSIS

updateplayers.pl -l FLA0031 -r 2

=head1 DESCRIPTION

"Update missing players, eg transfers or without English names, not in original populate of Players, but now in league.yaml." Update ratings for players from the given round. Also, update Members.


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
my $round = $script->round;

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
my $members = $d->resultset('Members');
my (%players, @members, @ratings);
my $leagues = $script->league;
my $league = League->new( leagues => $config{leagues}, id => $tournament );
my $filemembers = $league->members;
foreach my $member ( @$filemembers ) {
	my $id = $member->{id};
	my $dbmember = $members->find({ player => $id,
			tournament => $tournament });
	unless ( $dbmember ) {
		$players{$id} = {
			name => $member->{name},
			id => $member->{id},
			};
		push @members, {
			tournament => $tournament, player => $member->{id},
			absent => 'False', firstround => $round };
		push @ratings, { 
				player => $member->{id},
				tournament => $tournament,
				round => ($round - 1),
				value => $member->{rating} || 0 };
	}
}
my @players = values %players;
$players->update_or_create( $_ ) for @players;
$members->update_or_create( $_ ) for @members;
$ratings->update_or_create( $_ ) for @ratings;