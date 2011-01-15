#!/usr/bin/perl 

# Created: 西元2010年04月14日 21時33分46秒
# Last Edit: 2011  1月 15, 17時24分15秒
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

my %config = Config::General->new( "web/swiss.conf" )->getall;
my $name = $config{name};
require $name . ".pm";
my $model = "${name}::Schema";
my $modelfile = "$name/Model/DB.pm";
my $modelmodule = "${name}::Model::DB";
my $connect_info = $modelmodule->config->{connect_info};
my $d = $model->connect( @$connect_info );
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
    my $roundfile = $league->inspect( $g->compcompdirs . "/$round/round.yaml" );
    die "Round $round or $roundfile->{round}?" unless $round ==
	$roundfile->{round};
    my ( @allwhite, @allblack, %opponents, %roles, %dupe, @matches );
    my $byetablen = 0;
    my $activities = $roundfile->{activity};
    for my $key ( sort keys %$activities ) {
	my $topic = $activities->{$key};
	for my $form ( sort keys %$topic ) {
	    my $pairs = $topic->{$form};
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
		    any { $player eq $_->{white} or $player eq $_->{black}
			} @matches
				} @twoplayers;
		for my $id ( @twoplayers ) {
		    die "Fix $roles{$id}, $id at table $n, doing $key$form,"
			unless $league->is_member($id);
		    die "$id not member in db," unless
			$members->find({ player => $id });
		    my $score = $scores->find({ player => $id }); 
		    if ( $score ) {
			push @scores, $score->value || 0;
		    }
		}
		my $test = any { $_ != $scores[0] } @scores;
		my $float = $test? 1: 0;
		push @matches, {
		    tournament => $tourid,
		    round => $round,
		    pair => $n, 
		    white => $pair->{White},
		    black => $pair->{Black},
		    float => $float,
		    win => 'Unknown',
		    forfeit => 'Unknown',
		    tardy => 'Unknown'
			    };
		my $bign = max( $bytablen, $n );
		$byetablen = $bign;
	    }
	}
    }
    if ( exists $roundfile->{bye} ) {
	my $byeplayer = $roundfile->{bye};
	$opponents{$byeplayer} = 'Bye' if $byeplayer;
	$roles{$byeplayer} = 'Bye' if $byeplayer;
	push @matches, {
		tournament => $tourid,
		round => $round,
		pair => ++$byetablen, 
		white => $byeplayer,
		black => 'Bye',
		float => 1,
		win => 'White',
		forfeit => 'None',
		tardy => 'None'
			};
    }
    $opponents{$_} ||= 'Unpaired' for keys %members;
    $roles{$_} ||= 'Unpaired' for keys %members;
    for my $id ( keys %opponents ) { 
	warn "$id out of tournament, but playing $opponents{$id}," if
	    $members->find({ player => $id })->absent eq 'True';
    }
    print Dump \%opponents;
    print Dump \%roles;
    $cardset->populate( \@matches );
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
