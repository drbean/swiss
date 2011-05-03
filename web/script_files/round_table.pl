#!/usr/bin/perl 

# Created: 西元2010年04月14日 21時33分46秒
# Last Edit: 2011  5月 03, 11時47分53秒
# $Id$

=head1 NAME

round_table.pl - handpaired round updated to database

=head1 VERSION

Version 0.02

=cut

our $VERSION = '0.02';

use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/../lib";
use lib "web/lib";

use Cwd; use File::Basename;
use YAML qw/Dump/;
use List::Util qw/first max/;
use List::MoreUtils qw/any all/;

=head1 SYNOPSIS

In comp directory:

perl round_table.pl -l GL00027 -r 6

In round.yaml

activity:
  drbean:
    1:
      0:
        White: N9661740
        Black: U9714104
      3:
        White: N9532037
        Black: U9714127
  novak:
    1:
      1:
        White: T9722119
        Black: U9714111
      2:
        White: N9661742
        Black: N9661748

=cut

use Grades;
use Config::General;

my $script = Grades::Script->new_with_options;
my $tourid = $script->league || basename( getcwd );
my $league = League->new( id => $tourid );
my $g = Compcomp->new( league => $league );
my $leaguemembers = $league->members;
my %members = map { $_->{id} => $_ } @$leaguemembers;
my $lastround = $g->all_weeks->[-1];
my $round = $script->round || $lastround;

# use lib '../../swiss/web/lib';
use lib '/var/www/cgi-bin/swiss/lib';
use Swiss;
use Swiss::Model::DB;
use Swiss::Schema;

my $connect_info = Swiss::Model::DB->config->{connect_info};
my $d = Swiss::Schema->connect( @$connect_info );
my $foundround = $d->resultset('Round')->find( { tournament => $tourid } )
                ->value;
my $members = $d->resultset('Members')->search({ tournament => $tourid });
my $cardset = $d->resultset( "Matches" )->search({ tournament => $tourid });
my $scores = $d->resultset( "Scores" )->search({ tournament => $tourid });

=head1 DESCRIPTION

Generates {opponent,correct}.yaml files from handpairing in round.yaml.

Make sure each pair in each topic and form has a unique table number. TODO Do this Jigsaw round.yaml way.

Creating the pairs in round.yaml from a vim snippet is kind of fun. Anyway, it's necessary when swiss is not used to pair.

There's no Grades methods for accessing the round.yaml file. The bye player is recorded as, bye: 

Finally, the swiss database 'matches' table is updated.

=cut

run() unless caller;

sub run {
    my $config = $g->config($round);
    die "Round $round or $config->{round}?" unless $round ==
	$config->{round};
    die "Round $round? No such round" unless $round <= $config->{round};
    my ( @allwhite, @allblack, %opponents, %roles, %dupe, @matches );
    my $byetablen = 0;
    my $lates; $lates = $config->{late} if defined $config->{late};
    my $forfeits; $forfeits = $config->{forfeit} if defined $config->{forfeit};
    my $activities = $config->{activity};
    for my $key ( sort keys %$activities ) {
	my $topic = $activities->{$key};
	for my $form ( sort keys %$topic ) {
	    my $pairs = $topic->{$form};
	    $pairs = $config->{group};
	    my @white = map { $pairs->{$_}->{White} } keys %$pairs;
	    my @black = map { $pairs->{$_}->{Black} } keys %$pairs;
	    $dupe{ $_ }++ for ( @white, @black );
	    my @dupe = grep { $dupe{$_} != 1 } keys %dupe;
	    warn "$_ is dupe in $key topic, $form form" for @dupe;
	    @opponents{ @white } = @black;
	    @opponents{ @black } = @white;
	    @roles{ @white } = ('White') x @white;
	    @roles{ @black } = ('Black') x @black;

	    for my $n ( keys %$pairs ) {
		my $pair = $pairs->{$n};
		my @scores;
		my @twoplayers = values %$pair;
		next if all	{ my $player=$_;
		    any { $player eq $_->[3] or $player eq $_->[4]
			} @matches
				} @twoplayers;
		for my $id ( @twoplayers ) {
		    die "$roles{$id}, $id at table $n, doing $key$form, member?"
			unless $league->is_member($id);
		    die "$id not member in db," unless
			$members->find({ player => $id });
		    my $score = $scores->find({ player => $id }); 
		    if ( $score ) {
			push @scores, $score->value || 0;
		    }
		}
		my $float = ( any { $_ != $scores[0] } @scores ) ? 1: 0;
		push @matches, [
		$tourid, $round, $n, $pair->{White}, $pair->{Black}, $float,
		    'Unknown', 'Unknown', 'Unknown'
			    ];
		$byetablen = max( $byetablen, $n );
	    }
	}
    }
    if ( exists $config->{bye} ) {
	my $byeplayer = $config->{bye};
	$opponents{$byeplayer} = 'Bye' if $byeplayer;
	$roles{$byeplayer} = 'Bye' if $byeplayer;
	my $late = 'None';
	$late = 'White' if ( ( defined $lates ) and ( ref($lates) eq 'ARRAY' ) and
	    ( any { $_ eq $byeplayer } @$lates ) );
	push @matches, [
		    $tourid, $round, ++$byetablen, $byeplayer, 'Bye', 1,
				'White', 'None', $late
			];
    }
    $opponents{$_} ||= 'Unpaired' for keys %members;
    $roles{$_} ||= 'Unpaired' for keys %members;
    for my $id ( keys %opponents ) { 
	warn "$id out of tournament, but playing $opponents{$id}," if
	    $members->find({ player => $id })->absent eq 'True';
    }
    print Dump \%opponents;
    print Dump \%roles;
    uptodatepopulate( 'Matches', [ [ qw/
		tournament
		round
		pair
		white
		black
		float
		win
		forfeit
		tardy/ ],
                @matches ] );

    sub uptodatepopulate
    {
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

}

=head1 AUTHOR

Dr Bean C<< <drbean at cpan, then a dot, (.), and org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Dr Bean, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

# End of round_table.pl

# vim: set ts=8 sts=4 sw=4 noet:
