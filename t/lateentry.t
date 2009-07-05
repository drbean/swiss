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
	id => $_, name => chr($_+64), rating => 2000-2*$_, title => 'Nom') }
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
}

plan tests => 1 * blocks;

sub runAndCheck {
	my $lateentry = shift;
	runRound($lateentry);
	my $block = next_block;
	is_deeply( $block->input, $block->expected, $block->name );
}
runAndCheck(1);
runAndCheck(2);
runAndCheck(3);

__DATA__

=== Tourney 1 Round 1
--- input chomp entrycheck
0
--- expected yaml
0:
 -
  - 1
  - 2
0Bye:
 -
  - 3

