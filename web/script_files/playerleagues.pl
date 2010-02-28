#!perl

use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/../lib";

use Config::General;
use Cwd;
use File::Spec;
use List::MoreUtils qw/all/;
use YAML qw/LoadFile/;

BEGIN {
	my @MyAppConf = glob( "$Bin/../*.conf" );
	die "Which of @MyAppConf is the configuration file?"
				unless @MyAppConf == 1;
	my %config = Config::General->new($MyAppConf[0])->getall;
	$::name = $config{name};
	require "$::name.pm"; $::name->import;
	require "$::name/Schema.pm"; $::name->import;
}

my @leagueids = qw/GL00029 GL00030 GL00031 GL00034 FLA0016 /;
my $dir = ( File::Spec->splitdir(getcwd) )[-1];
$dir = qr/^(GL000|FLA)/ if $dir eq 'web';
@leagueids = grep m/$dir/, @leagueids;

no strict qw/subs refs/;
my $connect_info = "${::name}::Model::DB"->config->{connect_info};
# my $connect_info = [ 'dbi:SQLite:db/demo','','' ];
my $schema = "${::name}::Schema"->connect( @$connect_info );
use strict;

my $leagues = [
		[ qw/id name field/ ],
	[ "GL00029", "GL00029日語文共同學制虛擬班二", "中級英文聽說訓練" ],
	[ "GL00030", "GL00030日語文共同學制虛擬班二", "中級英文聽說訓練" ],
	[ "GL00031", "GL00031日語文共同學制虛擬班二", "中級英文聽說訓練" ],
	[ "GL00034", "GL00034日語文共同學制虛擬班二", "中級英文聽說訓練" ],
	[ "FLA0016", "FLA0016夜應外大學二甲", "英語會話" ],
	[ "access", "Self-Access Learning", "Listening" ],
	];

uptodatepopulate( 'Leagues', $leagues );

my ($leaguefile, $players);

for my $league ( 'GL00029', 'GL00030', 'GL00031', 'GL00034', 'FLA0016', ) {
	$leaguefile = LoadFile "/home/drbean/class/$league/league.yaml";
	push @{$players->{$league}},
		map {[ $_->{id}, $_->{name}, $_->{rating} ]}
					@{$leaguefile->{member}};
}

my @officials = ( [ qw/id name password/ ] );
push @officials, [split] for <<OFFICIALS =~ m/^.*$/gm;
193001	DrBean	ok
OFFICIALS
uptodatepopulate( 'Arbiters', \@officials );

my %players;
foreach my $league ( 'officials', @leagueids )
{
	next unless $players->{$league} and ref $players->{$league} eq "ARRAY";
	my @players = @{$players->{$league}};
	foreach ( @players )
	{
		$players{$_->[0]} = [ $_->[0], $_->[1], $_->[2] ];
	}
}
my $playerpopulator = [ [ qw/id name rating/ ], values %players ];
# uptodatepopulate( 'Players', $playerpopulator );

my @allLeaguePlayers;
foreach my $league ( @leagueids )
{
	my %members;
	next unless $players->{$league} and ref $players->{$league} eq "ARRAY";
	my @players = @{$players->{$league}};
	foreach my $player ( @players )
	{
		$members{$player->[0]} =  [ $league, $player->[0] ];
	}
	push @allLeaguePlayers, values %members;
}
# uptodatepopulate( 'Members', [ [ qw/league player/ ], @allLeaguePlayers ] );

sub uptodatepopulate
{
	my $class = $schema->resultset(shift);
	my $entries = shift;
	my $columns = shift @$entries;
	foreach my $row ( @$entries )
	{
		my %hash;
		@hash{@$columns} = @$row;
		$class->update_or_create(\%hash);
	}
}


=head1 NAME

script_files/playerleagues.pl.pl - populate leagues, players, members, roles, rolebrarer tables

=head1 SYNOPSIS

perl script_files/playerleagues.pl

=head1 DESCRIPTION

INSERT INTO players (id, name, password) VALUES (?, ?, ?)

=head1 AUTHOR

Dr Bean, C<drbean at (@) cpan dot, yes a dot, org>

=head1 COPYRIGHT


This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
