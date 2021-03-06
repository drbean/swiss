#!/usr/bin/perl

=head1 NAME

loadYAML.pl -- Load one text with questions from a YAML file

=head1 SYNOPSIS

loadYAMLid.pl data/business.yaml careercandidate

=head1 DESCRIPTION

Cut and paste from YAML into texts, questions tables 

But be careful with targets

=head1 AUTHOR

Sebastian Riedel, C<sri@oook.de>

=head1 COPYRIGHT


This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";

use Config::General;

my @MyAppConf = glob( "$FindBin::Bin/../*.conf" );
die "Which of @MyAppConf is the configuration file?"
			unless @MyAppConf == 1;
my %config = Config::General->new($MyAppConf[0])->getall;
my $name = $config{name};
require $name . ".pm";
my $model = "${name}::Schema";
my $modelfile = "$name/Model/DB.pm";
my $modelmodule = "${name}::Model::DB";
# require $modelfile;

my $connect_info = $modelmodule->config->{connect_info};
my $d = $model->connect( @$connect_info );

use YAML qw/LoadFile DumpFile/;
use IO::All;
my $league = $ARGV[0];
my $conversation = $ARGV[1];
my $file = "/home/drbean/class/$league/$conversation/opponent.yaml";
my $opponents = LoadFile $file;
my @opponents;
push @opponents, [qw/tournament player opponent round/];
for my $player ( keys %$opponents ) {
	if ( $player =~ m/bye/i ) {
		$player = $opponents->{$player};
		$opponents->{$player} = 'Bye';
		push @opponents, [ $league, $player, $opponents->{$player}, 1 ];
	}
	elsif ( $player =~ m/unpaired/i ) {
		my $absent = $opponents->{$player};
		for my $notplayer ( $absent ) {
			push @opponents, [ $league, $notplayer, 'Unpaired', 1 ];
		}
	}
	else { push @opponents, [ $league, $player, $opponents->{$player}, 1 ] }

}
my $t = $d->resultset('Opponents');
$t->populate(\@opponents);
