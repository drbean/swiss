#!usr/bin/perl

use lib qw/t lib/;

use strict;
use warnings;

use Games::Tournament::Swiss::Test;

plan tests => 1*blocks;

filters { player => [qw/player/],
		meeted => [qw/yaml/],
		tourney => [qw/tourney/],
		play => [qw/lines chomp array play/],
		game => [qw/chomp game/],
};

sub player { $p[shift]->met(@p); }
sub tourney { $s->met($p[shift], @p); }
sub play { my $players = shift;
$play->{$p[$players->[0]]->id}->{$p[$players->[1]]->id} };
sub game { my $game = shift; return 'undef' if $game =~m/^undef$/; $g[$game] };

my @x = game(undef);

run_is_deeply player => 'meeted';
run_is_deeply tourney => 'meeted';
run_is_deeply play => 'game';

use orz;
is_deeply($play->{$p[0]->id}->{$p[0]->id}, undef, 'play0');

[ $play->{$p[0]->id}->{$p[0]->id},	undef,	'#0	0	undef'],
[ $play->{$p[4]->id}->{$p[4]->id},	undef,	'#4	4	undef'],
[ $play->{$p[6]->id}->{$p[5]->id},	$g[11],	'#6	5	11'],
);

map { is_deeply( $_->[0], $_->[1,], $_->[2] ) } @tests;

__DATA__

=== p0
--- player
0

--- meeted
- ''
- ''
- 2
- ''
- 3
- ''
- ''
- 1

=== p7
--- player
7

--- meeted
--- [1,2,3,'','','','','']

=== p01
--- tourney
0

--- meeted
- ''
- ''
- 2
- ''
- 3
- ''
- ''
- 1

=== p71
--- tourney
7

--- meeted
--- [1,2,3,'','','','','']

=== play0
--- play
0
0

--- game
undef

=== play01
--- play
0
1

--- game
undef

=== play07
--- play
0
7

--- game
0

=== play70
--- play
7
0

--- game
0

=== play71
--- play
7
1

--- game
4

=== play25
--- play
2
5

--- game
6

=== play56
--- play
5
6

--- game
11
