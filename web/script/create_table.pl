#!/usr/bin/perl 

# Created: 西元2010年04月07日 09時52分04秒
# Last Edit: 2010  4月 17, 12時24分02秒
# $Id$

=head1 NAME

create_table.pl - Collate opponents, roles to create table card

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

use strict;
use warnings;
use Cwd; use File::Basename;
use YAML qw/Dump/;

=head1 SYNOPSIS

perl script_files/create_table.pl -l MIA0009 -r 5

=cut

use Grades;

my $script = Grades::Script->new_with_options;
my $id = $script->league || basename( getcwd );
my $league = League->new( id => $id );
my $g = Grades->new( league => $league );
my $lastround = $g->conversations->[-1];
my $round = $script->round || $lastround;

=head1 DESCRIPTION

Not having a Games::Tournament::Card-style table table in the database was a mistake. I now need to recreate it to determine the topic and form of the activity the players at it played. Name the table after the white player.

=cut

my $o = $g->opponents( $round );
my $r = $g->inspect( $g->compcompdirs . '/' . $round . '/role.yaml' );
my @w = grep { $r->{$_} eq 'White' } keys %$r;
my %t = map { $_ => { White => $_ , Black => $o->{$_} } } @w;
print Dump \%t;

=head1 AUTHOR

Dr Bean C<< <drbean at cpan, then a dot, (.), and org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Dr Bean, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

# End of create_table.pl

# vim: set ts=8 sts=4 sw=4 noet:
