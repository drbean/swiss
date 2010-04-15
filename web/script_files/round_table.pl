#!/usr/bin/perl 

# Created: 西元2010年04月14日 21時33分46秒
# Last Edit: 2010  4月 15, 08時41分02秒
# $Id$

=head1 NAME

round_table.pl - handpaired round updated to database

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/../lib";
use lib "web/lib";

use Cwd; use File::Basename;
use YAML qw/Dump/;
use List::MoreUtils qw/all/;

=head1 SYNOPSIS

perl round_table.pl -l GL00027 -r 6

=cut

use Grades;
use Config::General;

my $script = Grades::Script->new_with_options;
my $tourid = $script->league || basename( getcwd );
my $league = League->new( id => $tourid );
my $g = Grades->new( league => $league );
my $leaguemembers = $league->members;
my %members = map { $_->{id} => $_ } @$leaguemembers;
my $lastround = $g->conversations->[-1];
my $round = $script->round || $lastround;

my %config = Config::General->new( "web/swiss.conf" )->getall;
my $name = $config{name};
require $name . ".pm";
my $model = "${name}::Schema";
my $modelfile = "$name/Model/DB.pm";
my $modelmodule = "${name}::Model::DB";
my $connect_info = $modelmodule->config->{connect_info};
my $d = $model->connect( @$connect_info );
my $members = $d->resultset('Members')->search({ tournament => $tourid });

=head1 DESCRIPTION

Generates {opponent,correct}.yaml files from handpairing in round.yaml.

Creating the pairs in round.yaml from a vim snippet is kind of fun. Anyway, it's necessary. However, it's difficult to remember how to create opponent.yaml and correct.yaml in the REPL. So I'm dumping it here.

There's no Grades method for round.yaml file. The pairs in round.yaml are named after the White player.

Finally, the swiss database is updated.

=cut

sub run {
    my $roundfile = $g->inspect( $g->compcompdirs . "/$round/round.yaml" );
    my $pairs = $roundfile->{pair};
    my @white = keys %$pairs;
    die "Some white players not in league" unless
	all { $league->is_member($_) } @white;
    my %opponents = map { $_ => $pairs->{$_}->{Black} } @white;
    my %black = reverse %opponents;
    die "Some black players not in league" unless
	all { $league->is_member($_) } keys %black;
    @opponents{ keys %black } = values %black;
    $opponents{$_} ||= 'Unpaired' for keys %members;

    my %roles = map { $_ => 'White' } @white;
    @roles{ keys %black } = ('Black') x keys %black;
    $roles{$_} ||= 'Unpaired' for keys %members;

    my ( @opponents, @roles );
    #while ( my $member = $members->next ) { 
    #    my $id = $member->player;
    #    die "$id not in tournament," unless $league->is_member($id) or 
    #        $member->absent eq 'True';
    #    push @opponents, {
    #    	tournament => $tourid,
    #    	round => $round,
    #    	player => $id,
    #    	opponent => $opponents{$id} };
    #    push @roles, {
    #    	tournament => $tourid,
    #    	round => $round,
    #    	player => $id,
    #    	role => $roles{$id} };
    #}
    for my $id ( keys %opponents ) { 
	warn "$id not in tournament," unless $league->is_member($id) or 
	    $members->find({ player => $id })->absent eq 'True';
	push @opponents, {
		tournament => $tourid,
		round => $round,
		player => $id,
		opponent => $opponents{$id} };
	push @roles, {
		tournament => $tourid,
		round => $round,
		player => $id,
		role => $roles{$id} };
    }

    my $opponents = $d->resultset('Opponents');
    $opponents->populate( \@opponents );
    my $roles = $d->resultset('Roles');
    $roles->populate( \@roles );

    print Dump \%opponents;
    print Dump \%roles;
}

run unless caller;

=head1 AUTHOR

Dr Bean C<< <drbean at cpan, then a dot, (.), and org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Dr Bean, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

# End of round_table.pl

# vim: set ts=8 sts=4 sw=4 noet:
