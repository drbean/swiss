# DESCRIPTION:  Check that late entering players get assimilated
# Created:  西元2009年07月03日 12時18分05秒
# Last Edit: 2009  7月 23, 07時58分16秒

=head 3 TODO

After round 2, the pairings of the script differ from those of pair. So stop after round 2. It's not the purpose of the test to see if pairing is taking place correctly, but only to assimilate late entries.

=cut


our $VERSION =  0.1;

use lib qw/t lib/;

use strict;
use warnings;
use Test::Base;

BEGIN {
    $Games::Tournament::Swiss::Config::firstround = 1;
    @Games::Tournament::Swiss::Config::roles      = qw/White Black/;
    %Games::Tournament::Swiss::Config::scores      = (
    Win => 1, Draw => 0.5, Loss => 0, Absence => 0, Bye => 1 );
    $Games::Tournament::Swiss::Config::algorithm  =
      'Games::Tournament::Swiss::Procedure::FIDE';
}

use Games::Tournament::Contestant::Swiss;
use Games::Tournament::Swiss;
use Games::Tournament::Card;

my $n = 4;
my @lineup = map { Games::Tournament::Contestant::Swiss->new(
	id => $_+1, name => chr($_+65), rating => 2000-2*$_, title => 'M.') }
	    (0..$n-1);
my @late = map  { Games::Tournament::Contestant::Swiss->new(
	id => $_+1+$n, name => chr($_+97), rating => 1999-2*$_, title => 'M.') }
	    (0..$n-1);
 my $round = 0;
my $tourney = Games::Tournament::Swiss->new( rounds => 3, entrants => \@lineup);
$tourney->assignPairingNumbers;
$tourney->enter($late[ 0 ]);
$tourney->assignPairingNumbers;
$tourney->initializePreferences;
$tourney->initializePreferences until $lineup[0]->preference->role eq 
		$Games::Tournament::Swiss::Config::roles[0];

sub runRound {
	$tourney->assignPairingNumbers;
	my %brackets = $tourney->formBrackets;
	my $pairing  = $tourney->pairing( \%brackets )->matchPlayers;
	my $matches = $pairing->{matches};
	$tourney->{matches}->{$round} = $matches;
	my @games;
	for my $bracket ( keys %$matches )
	{
		my $tables = $matches->{$bracket};
		$_->result( {
			$Games::Tournament::Swiss::Config::roles[0] => 'Win',
			$Games::Tournament::Swiss::Config::roles[1] => 'Loss',
			} ) for @$tables;
		push @games, @$tables;
	}
	$tourney->collectCards( @games );
	$tourney->round(++$round);
};

sub numbercheck {
	my $latecomer = shift;
	my $entries = $tourney->entrants;
	+{ map { $_->name => $_->pairingNumber } @$entries }
}

sub prefcheck {
	my $entries = $tourney->entrants;
	+{ map {$_->name => [ $_->preference->role, $_->preference->strength ] }
			@$entries
	};
}

plan tests => 1 * blocks;

sub RunCheckEnter {
	runRound;
	my $block = next_block;
	is_deeply( $block->input, $block->expected, $block->name );
	$block = next_block;
	is_deeply( $block->input, $block->expected, $block->name );
	$tourney->enter($late[ shift ]);
}
RunCheckEnter(1);
RunCheckEnter(2);
RunCheckEnter(3);
RunCheckEnter(4);

__DATA__

=== Round 1 pairingnumbers
--- input chomp numbercheck
0
--- expected yaml
A: 1
a: 2
B: 3
C: 4
D: 5

=== Post-Round 1 prefs
--- input chomp prefcheck
0
--- expected yaml
A: [ Black, Strong ]
a: [ White, Strong ]
B: [ White, Strong ]
C: [ Black, Strong ]
D: [ ~,     Mild ]

=== Round 2 pairingnumbers
--- input chomp numbercheck
1
--- expected yaml
A: 1
a: 2
B: 3
b: 4
C: 5
D: 6

=== Post-Round 2 prefs
--- input chomp prefcheck
1
--- expected yaml
A: [ White, Mild ]
a: [ Black, Mild ]
B: [ Black, Mild ]
b: [ White, Strong ]
C: [ White, Mild ]
D: [ Black, Strong ]

=== Round 3 pairingnumbers
--- LAST
--- input chomp numbercheck
2
--- expected yaml
A: 1
a: 2
B: 3
b: 4
C: 5
c: 6
D: 7

=== Post-Round 3 prefs
--- input chomp prefcheck
2
--- expected yaml
A: [ Black, Strong ]
a: [ White, Strong ]
B: [ Black, Mild ]
b: [ Black, Mild ]
C: [ White, Absolute ]
c: [ Black, Strong ]
D: [ White, Mild ]

=== Round 4 pairingnumbers
--- input chomp numbercheck
3
--- expected yaml
A: 1
a: 2
B: 3
b: 4
C: 5
c: 6
D: 7
d: 8

=== Post-Round 4 prefs
--- input chomp prefcheck
3
--- expected yaml
A: [ Black, Strong ]
a: [ Black, Mild ]
B: [ Black, Mild ]
b: [ White, Strong ]
C: [ White, Mild ]
c: [ Black, Strong ]
D: [ Black, Strong ]
d: [ Black, Strong ]
