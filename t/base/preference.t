#!/usr/bin/perl

use lib qw/t lib/;

use strict;
use warnings;
use Games::Tournament::Swiss::Test -base; 

filters qw/lines chomp/;
filters { input => [ qw/updatepref/ ], expected => [ qw/array/ ] };

plan tests => 1 * blocks;

run_is_deeply input => 'expected';

sub updatepref {
	my $direction = shift;
	my $difference = shift;
	my $role = shift;
	my $oldRoles = shift;
	my $pref = Games::Tournament::Contestant::Swiss::Preference->new( direction => $direction, difference => $difference );
	$pref->update( $role, $oldRoles );
	return [ $pref->role, $pref->strength, $pref->lastTwo ];
}

__END__

=== Test 1
--- input
Black
0
Black
White,
--- expected
White
Strong
Black,White,

=== Test 2
--- input
Black
0
Black
Black,White,
--- expected
White
Absolute
Black,Black,

=== Test 3
--- input
Black
1
Black
White,
--- expected
White
Absolute
Black,White,

=== Test 4
--- input
Black
1
Black
Black,
--- expected
White
Absolute
Black,Black,

=== Test 5
--- input
Black
2
Black
--- expected
White
Absolute
Black,None,

=== Test 6
--- input
Black
0
White
Black,
--- expected
Black
Strong
White,Black,

=== Test 7
--- input
Black
1
White
White,
--- expected
Black
Absolute
White,White,

=== Test 8
--- input
Black
1
White
Black,
--- expected
Black
Mild
White,Black,

=== Test 9
--- input
Black
2
White
Black,Black,
--- expected
White
Strong
White,Black,

=== Test 10
--- input
White
0
White
Black,
--- expected
Black
Strong
White,Black,

=== Test 11
--- input
White
1
White
White,
--- expected
Black
Absolute
White,White,

=== Test 12
--- input
White
2
White
Black,
--- expected
Black
Absolute
White,Black,

=== Test 13
--- input
White
0
Black
--- expected
White
Strong
Black,None,

=== Test 13
--- input
White
1
Black
--- expected
White
Mild
Black,None,

=== Test 14
--- input
White
2
Black
--- expected
Black
Strong
Black,None,
