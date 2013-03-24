#!/usr/bin/perl 

# Created: 西元2011年05月02日 12時25分36秒
# Last Edit: 2013 Mar 24, 02:12:06 PM
# $Id$

=head1 NAME

update_db.pl - run updatematches.pl, updategrades.pl, updatescores.pl. updateround.pl

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

use strict;
use warnings;

use FindBin qw/$Bin/;

=head1 SYNOPSIS

perl web/script_files/update_db.pl -l MIA0012 -r 5

=cut

=head1 DESCRIPTION

Updates database, running 4 scripts, updatematches.pl, updategrades.pl, updatescores.pl. updateround.pl.


=cut

require "/home/drbean/swiss/web/script_files/updatematches.pl";
run();

require "/home/drbean/swiss/web/script_files/updategrades.pl";
run();

require "/home/drbean/swiss/web/script_files/updatescores.pl";
run();

require "/home/drbean/swiss/web/script_files/updateround.pl";
run();

=head1 AUTHOR

Dr Bean C<< <drbean at cpan, then a dot, (.), and org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2011 Dr Bean, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

# End of update_db.pl

# vim: set ts=8 sts=4 sw=4 noet:


