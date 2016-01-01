#!/usr/bin/perl 

# Created: 11/10/2013 04:05:43 PM
# Last Edit: 2016 Jan 01, 13:44:09
# $Id$

=head1 NAME

chdir.pl - FindBin will find in this file's dir rather than master script

=cut

use strict;
use warnings;

=head1 SYNOPSIS

Trying to get update_db not to set $Bin to /usr/local/bin, but dir of required modules in /home/drbean/swiss

=cut

use FindBin qw/$Bin/;

=head1 DESCRIPTION



=cut

chdir '/home/drbean/swiss/web/script/';

sub run {
    1;
}

=head1 AUTHOR

Dr Bean C<< <drbean at cpan, then a dot, (.), and org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2013 Dr Bean, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

# End of chdir.pl

# vim: set ts=8 sts=4 sw=4 noet:


