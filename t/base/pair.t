#!/usr/bin/perl

use lib qw/t lib/;

use strict;
use warnings;

use Games::Tournament::Swiss::Test;

plan tests => 1 * blocks;

filters { input => [qw/chomp met/],
		expected => [qw/yaml/]
};

sub met { my $n = shift; $p[$n]->met(@p); }

my @x = $p[7]->met(@p);

run_is_deeply input => 'expected';

__DATA__

=== p0
--- input
0

--- expected
- ''
- ''
- 2
- ''
- 3
- ''
- ''
- 1

=== p7
--- input
7

--- expected
--- [1,2,3,'','','','','']

