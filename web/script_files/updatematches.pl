#!/usr/bin/perl

=head1 NAME

updatematches.pl - Enter results of matches in database via script

=head1 SYNOPSIS

updatematches.pl -l FLA0018 -r n

=head1 DESCRIPTION

This script is run after play is finished in one round and before the next round is paired and played.

The result of play in round n, whether a win for Black or for White, or a draw, is updated in the 'matches' table.

This table's columns and possible values, (apart from the primary key columns, 'tournament', 'round' and 'pair',) are 'win': 'White', 'Black', 'Draw,' 'None' or 'Unknown'; 'forfeit': 'White', 'Black', 'Both', 'None' or 'Unknown'; and 'tardy': 'White', 'Black', 'Both', 'None' or 'Unknown'.

The default for n, the last round, is found from the weeks of the league that is participating in the tournament, using Grades.pm, and in particular, CompComp.

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
use lib "web/lib";

use IO::All;
my $io = io '-';

use Grades;

use Config::General;

sub run {
    my $script = Grades::Script->new_with_options;
    my $tournament = $script->league or die "League id?";

    my %config = Config::General->new( "web/swiss.conf" )->getall;
    my $name = $config{name};
    require $name . ".pm";
    my $model = "${name}::Schema";
    my $modelfile = "$name/Model/DB.pm";
    my $modelmodule = "${name}::Model::DB";
    my $connect_info = $modelmodule->config->{connect_info};
    my $d = $model->connect( @$connect_info );

    my $league = League->new( leagues =>
	$config{leagues}, id => $tournament );
    my $comp = CompComp->new( league => $league );
    my $thisweek = $league->approach eq 'CompComp'?
	$comp->all_weeks->[-1]: 0;
    my $round = $script->round || $thisweek || 1;
    my $matches = $d->resultset('Matches')->search({
	tournament => $tournament,
	round => $round });

    my $config = $comp->config( $round );
    my $forfeiters = $config->{forfeiters};
    my $tardies = $config->{tardies};
    my $pairs = $comp->tables( $round );
    $io->print( $league->id . " Tournament Results, Round $round\n" .
	"Table\tWhite\tBlack\tWin\tForfeit\tTardy\n" );
    while ( my $match = $matches->next ) {
	my @roles = qw/white black/;
	my $table = $match->pair;
	my $result = $comp->scores( $round, $table );
	my %id = map { $_ => $match->$_ } @roles;
	my %roleplayer = reverse %id;
	for my $role ( @roles ) {
	    my $Role = ucfirst $role;
	    die "Pair $table, $Role: $id{$role} or $pairs->{$table}->{$Role}?"
		unless $id{$role} eq $pairs->{$table}->{$Role};
	}
	my @id = values %id;
	my %values;
	if ( $result->{$id[0]} > $result->{$id[1]} ) {
	    $values{win} = $roleplayer{$id[0]};
	}
	elsif ( $result->{$id[0]} < $result->{$id[1]} ) {
	    $values{win} = $roleplayer{$id[1]};
	}
	else { $values{win} = "Both" }
	my @forfeit = grep( ( $_ eq $id{$roles[0]} or $_ eq $id{$roles[1]} ),
		    @$forfeiters);
	if ( @forfeit == 0 ) { $values{forfeit} = 'None' }
	elsif ( @forfeit = 1 ) { $values{forfeit} = $forfeit[0] }
	else { $values{forfeit} = 'Both'; $values{win} = 'None' }
	my @tardy = grep( ( $_ eq $id{$roles[0]} or $_ eq $id{$roles[1]} ),
		    @$tardies);
	if ( @tardy == 0 ) { $values{tardy} = 'None' }
	elsif ( @tardy = 1 ) { $values{tardy} = $tardy[0] }
	else { $values{tardy} = 'Both' }
	$match->update({
		win => $values{win},
		forfeit => $values{forfeit},
		tardy => $values{tardy} });
	$io->print( "$table\t@id{@roles}\t@values{qw/win forfeit tardy/}\n" );
    }
}

run() unless caller;

1;

# vim: set ts=8 sts=4 sw=4 noet:
