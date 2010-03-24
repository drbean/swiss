#!perl

use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/../lib";

use Config::General;

BEGIN {
	my @MyAppConf = glob( "$Bin/../*.conf" );
	die "Which of @MyAppConf is the configuration file?"
				unless @MyAppConf == 1;
	%::config = Config::General->new($MyAppConf[0])->getall;
	$::name = $::config{name};
	require "$::name.pm"; $::name->import;
	require "$::name/Schema.pm"; $::name->import;
}

no strict qw/subs refs/;
my $connect_info = "${::name}::Model::DB"->config->{connect_info};
my $schema = "${::name}::Schema"->connect( @$connect_info );
use strict;

=head1 NAME

pairseat.pl - Seat pairs at tables in order

=head1 SYNOPSIS

perl script_files/pairseat.pl -l tournament -s round

=head1 DESCRIPTION

Seat players at tables in a 2-player competition tournament, Black, White, Black, White, with the higher-rated players at the back of the room.

=head1 AUTHOR

Dr Bean, C<drbean at (@) cpan dot, yes a dot, org>

=head1 COPYRIGHT


This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

package Script;
use strict;
use warnings;
use Moose;
with 'MooseX::Getopt';

has 'man' => (is => 'ro', isa => 'Bool');
has 'help' => (is => 'ro', isa => 'Bool');
has 'tournament' => (traits => ['Getopt'], is => 'ro', isa => 'Str',
		cmd_aliases => 'l',);
has 'round' => (traits => ['Getopt'], is => 'ro', isa => 'Str',
		cmd_aliases => 'r',);
has 'latex' => (is => 'ro', isa => 'Bool');


package main;

use strict;
use warnings;
use Pod::Usage;
use Text::Template;
use IO::All;
use YAML qw/LoadFile/;
use List::Util qw/first/;
use List::MoreUtils qw/any all/;
use Net::FTP;

use Games::Tournament::Contestant;
use Games::Tournament::Card;

run() unless caller();


sub run {
	my $script = Script->new_with_options;
	pod2usage(1) if $script->help;
	pod2usage(-exitstatus => 0, -verbose => 2) if $script->man;
	my $league = $script->tournament;
	my $tournament = $schema->resultset( 'Tournaments' )->find(
				{ id => $league });
	my $round = $script->round;
	my $members = $tournament->members;
	my @role = Games::Tournament::Swiss::Config->roles;
	my ( @games, @checkedids, @members, @nonplayers );
	while ( my $member = $members->next ) {
		my $myid = $member->player;
		next if any { $myid eq $_ } @checkedids;
		my $score = $member->score->score;
		my $rating = $member->rating->find({round => $round-1})->value;
		my $player = Games::Tournament::Contestant->new( 
			id => $myid, name => $member->profile->name,
			rating => $rating, score => $score );
		push @members, $player;
		my $myrole = $member->role->find({ tournament => $league, round =>
				$round }) or die "no round $round";
		my $role = $myrole->role;
		if ( $role eq 'Unpaired' or $role eq 'Bye' ) {
			push @nonplayers, $player;
			next;
		}
		my $other = $member->opponent->find({
			tournament => $league, round => $round } )->other;
		my $otherscore = $other->score->find({
				tournament => $league } )->score;
		my $otherrating = $other->rating->find({
				round => $round-1})->value;
		my $oppid = $other->id;
		my $opponent = Games::Tournament::Contestant->new( 
			id => $oppid, name => $other->name,
			rating => $otherrating, score => $otherscore );
		push @members, $opponent;
		my $otherrole = first { $_ ne $role } @role;
		my $game = Games::Tournament::Card->new( 
			contestants => { $role => $player, $otherrole => $opponent } );
		push @games, $game;
		push @checkedids, $myid, $oppid;
	}
	my $swiss = Games::Tournament::Swiss->new( rounds => $tournament->rounds,
		entrants => \@members );
	@games = reverse $swiss->orderPairings( @games );
	my $latex = $script->latex;
	my $filetype = $latex? "tex": "html";
	my $fileprefix = $latex? "latex": "html";
	my $config = LoadFile "$::config{leagues}/$league/league.yaml";
	my $room = $config->{room};
	my $rooms = "$::config{leagues}/rooms";
	my $roomconfig = LoadFile "$rooms/$room/config.yaml";
	my @stages = qw/expert pair/;
	my $arrangement = { expert => $roomconfig->{pairexperts},
						pair => $roomconfig->{pairs}, };
	my $colors = $roomconfig->{colors};
	my $t = Text::Template->new(TYPE=>'FILE', SOURCE=>
		"$::config{leagues}/rooms/$config->{room}/${fileprefix}seats.tmpl",
						DELIMITERS => ['[*', '*]']);
	my %seatingcharts = map { $_ =>
			{ league => $league, round => $round, stage => $_ } } @stages;
	foreach my $n (0 .. $#games) {
		my $game = $games[$n];
		my $table = $n+1;
		foreach my $stage ( @stages ) {
			my $position = $arrangement->{$stage}->{$table};
			my @seat = map { "s$_" } @$position;
			for my $n ( 0 .. $#role ) {
				my $player = $game->contestants->{$role[$n]};
				my $id = $player->id;
				my $name = $player->name;
				warn "$role[$n] player in seat $seat[$n] at table $table?"
								unless $id;
				$seatingcharts{$stage}->{$seat[$n]} = { id => $id,
							name => $name,
							color => $colors->{$table},
							team => ( 1+@games - $table ) . " $role[$n]" };
			}
		}
	}
	foreach my $stage (@stages) {
		my $diagram = $t->fill_in( HASH => $seatingcharts{$stage} );
		io("$::config{leagues}/$league/comp/${stage}seat.$filetype")
			->print($diagram);
		if ( $filetype eq 'html' ) {
			my $web = Net::FTP->new( 'web.nuu.edu.tw' ) or warn "web.nuu?";
			$web->login("greg", "1514") or warn "login: greg?";
			$web->cwd( 'public_html' ) or die "No cwd to public_html,";
			$web->put(
				"$::config{leagues}/$league/comp/${stage}seat.$filetype",
				"$league$stage.html") or die "put file?";
		}
	}
}
