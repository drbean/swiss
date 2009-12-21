#!/usr/bin/perl

use YAML qw/LoadFile DumpFile/;
use IO::All;

my $league = LoadFile "/home/drbean/class/$ARGV[0]/league.yaml";
my $members = $league->{member};

my $io = io '-';
for my $member ( @$members ) {
	my $name = $member->{name};
	my $rating = $member->{rating};
	$io->append( "$member->{id}\t$name\t$rating\t1\n") if
		$name =~ m/^[A-Za-z'-]+$/;
}
