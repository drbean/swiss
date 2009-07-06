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

my $n = 20;
my @lineup = map { Games::Tournament::Contestant::Swiss->new(
	id => $_, name => chr($_+64), rating => 2002-2*$_, title => 'Nom') }
	    (1..$n);
my @late = map  { Games::Tournament::Contestant::Swiss->new(
	id => $n+$_, name => chr($_+96), rating => 2001-2*$_, title => 'Nom') }
	    (1..$n);
my $tourney = Games::Tournament::Swiss->new( rounds => 2, entrants => \@lineup);
my $round = 0;
$tourney->round($round);
$tourney->assignPairingNumbers;
$tourney->initializePreferences;
$tourney->initializePreferences until $lineup[0]->preference->role eq 
		$Games::Tournament::Swiss::Config::roles[0];

sub runRound {
	my $one = shift;
	$tourney->enter($late[$one]);
	$tourney->assignPairingNumbers;
	my %brackets = $tourney->formBrackets;
	my $pairing  = $tourney->pairing( \%brackets )->matchPlayers;
	my $matches = $pairing->{matches};
	$tourney->{matches}->{$round} = $matches;
	my @games;
	my $results = shift;
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
	$tourney->round($round);
};

sub entrycheck {
	my $latecomer = shift;
	my $entries = $tourney->entrants;
	+{ map { $_->name => $_->pairingNumber } @$entries }
}

plan tests => 1 * blocks;

sub runAndCheck {
	my $lateentry = shift;
	runRound($lateentry);
	my $block = next_block;
	is_deeply( $block->input, $block->expected, $block->name );
}
runAndCheck(0);
runAndCheck(1);
runAndCheck(2);

__DATA__

=== Round 1
--- input chomp entrycheck
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

=== Round 2
--- input chomp entrycheck
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

=== Round 3
--- input chomp entrycheck
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
