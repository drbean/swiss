#!/usr/bin/perl

=head1 NAME

remove_players.pl - Remove players in database not in league.yaml

=head1 SYNOPSIS

remove_players.pl -l FLA0031

=head1 DESCRIPTION

"Delete players, eg transfers or without English names, who were in original populate of Players, but are not now in league.yaml members." They are probably now in out. Remove from ratings, members.

Be careful. They may be in matches. Don't use this after the first match.

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

use List::MoreUtils qw/none/;
use IO::All;
my $io = io '-';

use Grades;

my $script = Grades::Script->new_with_options;
my $tournament = $script->league;

use Swiss;
use Swiss::Model::DB;
use Swiss::Schema;

my $config = Swiss->config;
my $connect_info = Swiss::Model::DB->config->{connect_info};
my $d = Swiss::Schema->connect( @$connect_info );
my $players = $d->resultset('Players');
my $ratings = $d->resultset('Ratings')->search({ tournament => $tournament });
my $members = $d->resultset('Members')->search({ tournament => $tournament });
my (%players, @newbies, @absentees, @returnees, @ratings);
my $leagues = $script->league;
my $league = League->new( leagues => $config->{leagues}, id => $tournament );
my $membersonfile = $league->members;
my $out = $league->yaml->{out};
my %chinese = map { $_->{id} => $_->{name} } @$out;
my @ids = map { $_->{id} } @$membersonfile;
while ( my $dbmember = $members->next ) {
	my $id = $dbmember->player;
	if ( none { $_ eq $id } @ids ) {
		print "Deleting $id\t$chinese{$id}\n";
		$dbmember->delete;
	}
}
