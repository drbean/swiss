package Games::Tournament::Swiss::Test;

use lib qw/t lib/;

use strict;
use warnings;
# use Test::Base -base;
use Test::More;

BEGIN {
	$Games::Tournament::Swiss::Config::firstround = 1;
	$Games::Tournament::Swiss::Config::algorithm = 'Games::Tournament::Swiss::Procedure::Dummy';
}

our @EXPORT = qw/$r1 $r2 $r3 $r4 $r5 $r6 $r7 $r8 @p @g @g1 @g2 @g3 @g4 @g5 @g6 @g7 @g8 @b1 @b2 @b3 @b4 @b5 @b6 @b7 @b8 $t $meets $play @pair/;

use Games::Tournament::Contestant::Swiss;
# use base Games::Tournament::Swiss;
require 'Games/Tournament/Swiss.pm';
use Games::Tournament::Card;
use Games::Tournament::Swiss::Procedure;

our @p;
$p[0] = Games::Tournament::Contestant::Swiss->new( id => 9430101, name => 'Roy', score => 0, title => 'Expert', rating => 100,  );
$p[1] = Games::Tournament::Contestant::Swiss->new( id => 9430102, name => 'Ron', score => 0, title => 'Expert', rating => 80,  );
$p[2] = Games::Tournament::Contestant::Swiss->new( id => 9430103, name => 'Rog', score => 0, title => 'Expert', rating => '50', );
$p[3] = Games::Tournament::Contestant::Swiss->new( id => 9430104, name => 'Ray', score => 0, title => 'Novice', rating => 25, );
$p[4] = Games::Tournament::Contestant::Swiss->new( id => 9430105, name => 'Rob', score => 0, title => 'Novice', rating => 1, );
$p[5] = Games::Tournament::Contestant::Swiss->new( id => 9430108, name => 'Red', score => 0, title => 'Novice', rating => 0, );
$p[6] = Games::Tournament::Contestant::Swiss->new( id => 9430107, name => 'Reg', score => 0, title => 'Novice', rating => 0, );
$p[7] = Games::Tournament::Contestant::Swiss->new( id => 9430109, name => 'Rex', score => 0, title => 'Novice', rating => 0, );
$p[8] = Games::Tournament::Contestant::Swiss->new( id => 9430110, name => 'Rod', score => 0, title => 'Novice', rating => 0, );
$p[9] = Games::Tournament::Contestant::Swiss->new( id => 9430106, name => 'Ros', score => 0, title => 'Novice', rating => 0, );

# @p[8..31] = ( $p[7] ) x 24;

use orz;

$p[10] = Games::Tournament::Contestant::Swiss->new( id => 9430108, name => 'Red', score => 0, title => 'Novice', rating => 0, );
$p[11] = Games::Tournament::Contestant::Swiss->new( id => 9430108, name => 'Red', score => 0, title => 'Novice', rating => 0, );
$p[12] = Games::Tournament::Contestant::Swiss->new( id => 9430108, name => 'Red', score => 0, title => 'Novice', rating => 0, );
$p[13] = Games::Tournament::Contestant::Swiss->new( id => 9430108, name => 'Red', score => 0, title => 'Novice', rating => 0, );
$p[14] = Games::Tournament::Contestant::Swiss->new( id => 9430108, name => 'Red', score => 0, title => 'Novice', rating => 0, );
$p[15] = Games::Tournament::Contestant::Swiss->new( id => 9430108, name => 'Red', score => 0, title => 'Novice', rating => 0, );
$p[16] = Games::Tournament::Contestant::Swiss->new( id => 9430108, name => 'Red', score => 0, title => 'Novice', rating => 0, );
$p[17] = Games::Tournament::Contestant::Swiss->new( id => 9430108, name => 'Red', score => 0, title => 'Novice', rating => 0, );

no orz;

our $t = Games::Tournament::Swiss->new(
	rounds => 'what', entrants => \@p);

use orz;

our @g;
$g[0] = Games::Tournament::Card->new( round => 1, contestants => {Black => $p[7], White => $p[0]}, result => {Black => 'Loss'} );
$g[1] = Games::Tournament::Card->new( round => 2, contestants => {Black => $p[2], White => $p[0]}, result => {Black => 'Loss'} );
$g[2] = Games::Tournament::Card->new( round => 3, contestants => {Black => $p[4], White => $p[0]}, result => {Black => 'Loss'} );

$g[3] = Games::Tournament::Card->new( round => 1, contestants => {Black => $p[6], White => $p[1]}, result => {Black => 'Loss'} );
$g[4] = Games::Tournament::Card->new( round => 2, contestants => {Black => $p[7], White => $p[1]}, result => {Black => 'Loss'} );
$g[5] = Games::Tournament::Card->new( round => 3, contestants => {Black => $p[3], White => $p[1]}, result => {Black => 'Loss'} );

$g[6] = Games::Tournament::Card->new( round => 1, contestants => {Black => $p[5], White => $p[2]}, result => {Black => 'Loss'} );
$g[7] = Games::Tournament::Card->new( round => 3, contestants => {Black => $p[7], White => $p[2]}, result => {Black => 'Loss'} );

$g[8] = Games::Tournament::Card->new( round => 1, contestants => {Black => $p[4], White => $p[3]}, result => {Black => 'Loss'} );
$g[9] = Games::Tournament::Card->new( round => 2, contestants => {Black => $p[6], White => $p[3]}, result => {Black => 'Loss'} );

$g[10] = Games::Tournament::Card->new( round => 2, contestants => {Black => $p[5], White => $p[4]}, result => {Black => 'Loss'} );

$g[11] = Games::Tournament::Card->new( round => 3, contestants => {Black => $p[6], White => $p[5]}, result => {Black => 'Loss'} );

# $t->collectCards(@g);
# $t->calculateScores(3);

no orz; 

$t->assignPairingNumbers( @p );

# $_->copyCard(@g) foreach @p;

our @b1 = $t->formBrackets;
our $r1 = $t->pairing( \@b1 );

$r1->matchPlayers;
our @g1 = map { @{ $_ } } @{$r1->matches};
$_->result({Black => 'Loss'}) for @g1;
$t->collectCards(@g1);
$t->calculateScores(1);
our @b2 = $t->formBrackets;
our $r2 = $t->pairing( \@b2 );

$r2->matchPlayers;
our @g2 = map { @{ $_ } } @{$r2->matches};
$_->result({Black => 'Loss'}) for @g2;
$t->collectCards(@g2);
$t->calculateScores(2);
our @b3 = $t->formBrackets;
our $r3 = $t->pairing( \@b3 );

$r3->matchPlayers;
our @g3 = map { @{ $_ } } @{$r3->matches};
$_->result({Black => 'Loss'}) for @g3;
$t->collectCards(@g3);
$t->calculateScores(3);
our @b4 = $t->formBrackets;
our $r4 = $t->pairing( \@b4 );

$r4->matchPlayers;
our @g4 = map { @{ $_ } } @{$r4->matches};
$_->result({Black => 'Loss'}) for @g4;
# $_->copyCard(@g4) foreach @p;
$t->collectCards(@g4);
$t->calculateScores(4);
our @b5 = $t->formBrackets;
our $r5 = $t->pairing( \@b5 );

$r5->matchPlayers;
our @g5 = map { @{ $_ } } @{$r5->matches};
$_->result({Black => 'Loss'}) for @g5;
# $_->copyCard(@g5) foreach @p;
$t->collectCards(@g5);
$t->calculateScores(5);
our @b6 = $t->formBrackets;
our $r6 = $t->pairing( \@b6 );

use orz;

$r6->matchPlayers;
our @g6 = map { @{ $_ } } @{$r6->matches};
$_->result({Black => 'Loss'}) for @g6;
# $_->copyCard(@g6) foreach @p;
$t->collectCards(@g6);
$t->calculateScores(6);
our @b7 = $t->formBrackets;
our $r7 = $t->pairing( \@b7 );

$r7->matchPlayers;
our @g7 = map { @{ $_ } } @{$r7->matches};
$_->result({Black => 'Loss'}) for @g7;
# $_->copyCard(@g7) foreach @p;
$t->collectCards(@g7);
$t->calculateScores(7);
our @b8 = $t->formBrackets;
our $r8 = $t->pairing( \@b8 );

$r8->matchPlayers;
our @g8 = map { @{ $_ } } @{$r8->matches};
$_->result({Black => 'Loss'}) for @g8;
# $_->copyCard(@g8) foreach @p;
$t->collectCards(@g8);
$t->calculateScores(8);
our @b9 = $t->formBrackets;
our $r9 = $t->pairing( \@b9 );

no orz;

our @meets = $t->met($p[7],$p[0],$p[1],$p[2],$p[3],$p[4],$p[5],$p[6]);

package Games::Tournament::Swiss::Test::Filter;

use Test::Base::Filter -Base;

__DATA__


# See what arguments are being passed thru
# ">" . $players->[0] . "< >" . $players->[1] . "<"; }
