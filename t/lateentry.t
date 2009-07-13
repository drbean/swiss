#
#===============================================================================
#
#         FILE:  lateentry.t
#
#  DESCRIPTION:  Check that late entering players get assimilated
#
#        FILES:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Dr Bean (), <drbean at (yes, an @>, cpan dot (a ., of course) org>
#      COMPANY:  
#      VERSION:  0.1
#      CREATED:  西元2009年07月03日 12時18分05秒
#     REVISION:  ---
#===============================================================================

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
my $tourney = Games::Tournament::Swiss->new( rounds => 2, entrants => \@lineup);
my $round = 0;
$tourney->round($round);
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

sub scorecheck {
	my $latecomer = shift;
	my $score = $late[$latecomer]->score;
}

sub prefcheck {
	my $ones = shift;
	+{ map { $_ => { prefer => $late[$_]->preference->role,
		degree => $late[$_]->preference->strength } }
			0 .. $ones
	};
}

plan tests => 1 * blocks;

sub runAndCheck {
	runRound;
	my $block = next_block;
	is_deeply( $block->input, $block->expected, $block->name );
	$block = next_block;
	is_deeply( $block->input, $block->expected, $block->name );
	$tourney->enter($late[ shift ]);
}
runAndCheck(1);
runAndCheck(2);
runAndCheck(3);

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

=== Round 1 prefs
--- input chomp prefcheck
0
--- expected yaml
prefer: White
degree: Strong

=== Round 2 pairingnumbers
--- input chomp numbercheck
0
--- expected yaml
A: 1
a: 2
B: 3
b: 4
C: 5
D: 6

=== Round 2 prefs
--- input chomp prefcheck
1
--- expected yaml
0:
  prefer: Black
  degree: Mild
1:
  prefer: White
  degree: Strong

=== Round 3 pairingnumbers
--- input chomp numbercheck
0
--- expected yaml
A: 1
a: 2
B: 3
b: 4
C: 5
c: 6
D: 7

=== Round 3 prefs
--- input chomp prefcheck
2
--- expected yaml
0:
  prefer: White
  degree: Strong
1:
  prefer: White
  degree: Strong
2:
  prefer: White
  degree: Strong


=== Round 1 pairingnumbers
--- input chomp numbercheck
0
--- expected yaml
A: 1
a: 2
B: 3
C: 4
D: 5
E: 6
F: 7
G: 8
H: 9
I: 10
J: 11
K: 12
L: 13
M: 14
N: 15
O: 16
P: 17
Q: 18
R: 19
S: 20
T: 21

=== Round 1 prefs
--- input chomp prefcheck
0
--- expected yaml
prefer: White
degree: Strong

=== Round 2 pairingnumbers
--- input chomp numbercheck
0
--- expected yaml
A: 1
a: 2
B: 3
b: 4
C: 5
D: 6
E: 7
F: 8
G: 9
H: 10
I: 11
J: 12
K: 13
L: 14
M: 15
N: 16
O: 17
P: 18
Q: 19
R: 20
S: 21
T: 22

=== Round 2 prefs
--- input chomp prefcheck
1
--- expected yaml
0:
  prefer: Black
  degree: Mild
1:
  prefer: White
  degree: Strong

=== Round 3 pairingnumbers
--- input chomp numbercheck
0
--- expected yaml
A: 1
a: 2
B: 3
b: 4
C: 5
c: 6
D: 7
E: 8
F: 9
G: 10
H: 11
I: 12
J: 13
K: 14
L: 15
M: 16
N: 17
O: 18
P: 19
Q: 20
R: 21
S: 22
T: 23

=== Round 3 prefs
--- input chomp prefcheck
2
--- expected yaml
0:
  prefer: White
  degree: Strong
1:
  prefer: White
  degree: Strong
2:
  prefer: White
  degree: Strong

