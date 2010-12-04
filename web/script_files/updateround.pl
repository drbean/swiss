#!/usr/bin/perl

=head1 NAME

updateround.pl - Set round in database via script

=head1 SYNOPSIS

perl web/script_files/updateround.pl -l FLA0018 -r n

=head1 DESCRIPTION

This script is run after play is finished in one round and before the next round is paired and played.

This could be done with a REPL or the database CLI, but I forget to do it.

The default round is 1. If not set on the command line, the last conversation in comp is used to set the round.

=head1 AUTHOR

Dr Bean

=head1 COPYRIGHT


This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/../lib";
use lib "web/lib";

use IO::All;
my $io = io '-';
use Config::General;

use Grades;

sub run {
    my $script = Grades::Script->new_with_options;
    my $tournament = $script->league or die "League id?";

    my %config = Config::General->new( "web/swiss.conf" )->getall;
    my $name = $config{name};
    require $name . ".pm";
    my $model = "${name}::Schema";
    my $modelfile = "$name/Model/DB.pm";
    my $modelmodule = "${name}::Model::DB";
    my $connect_info = $modelmodule->config->{connect_info};
    my $d = $model->connect( @$connect_info );

    my $league = League->new( leagues =>
	$config{leagues}, id => $tournament );
    my $comp = Compcomp->new( league => $league );
    my $thisweek = $league->approach eq 'Compcomp'?
	$comp->all_weeks->[-1]: 0;
    my $round = $script->round || $thisweek || 1;
    my $roundset = $d->resultset('Round')->find({ tournament => $tournament });
    $roundset->update({ value => $round });
    $io->print( "$tournament: updated to Round $round\n" );
}

run() unless caller;

1;

# vim: set ts=8 sts=4 sw=4 noet:
