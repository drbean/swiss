package Swiss::View::TT;

use strict;
use base 'Catalyst::View::TT';

__PACKAGE__->config(
	# Change default TT extension
	TEMPLATE_EXTENSION => '.tt2',
	# Set the location for TT files
	INCLUDE_PATH => [
	       Swiss->path_to( 'root/src' ),
	   ],
);

=head1 NAME

Swiss::View::TT - TT View for Swiss

=head1 DESCRIPTION

TT View for Swiss. 

=head1 AUTHOR

=head1 SEE ALSO

L<Swiss>

A clever guy

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
