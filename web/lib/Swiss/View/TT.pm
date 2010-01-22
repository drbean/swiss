package Swiss::View::TT;

use strict;
use base 'Catalyst::View::TT';
use Template::Stash;

$Template::Stash::SCALAR_OPS->{lc} = sub {
	my ($string ) = @_;
	return lc $string;
};

$Template::Stash::LIST_OPS->{abbrevs} = sub {
	my ( $list, @roles ) = @_;
	return [ map { ( $_ eq $roles[0] or $_ eq $roles[1] ) ?
			substr( $_, 0, 1 ) : '-' } @$list ];
};

$Template::Stash::LIST_OPS->{substrs} = sub {
	my ($list, $offset, $length ) = @_;
	return [ map { substr( $_, $offset, $length ) } @$list ];
};

$Template::Stash::LIST_OPS->{map} = sub {
	my ($list, $sub ) = @_;
	return [ map { $sub->($_) } @$list ];
};

__PACKAGE__->config(
	# Change default TT extension
	TEMPLATE_EXTENSION => '.tt2',
	# Set the location for TT files
	INCLUDE_PATH => [
	       Swiss->path_to( 'root/src' ),
	   ],
	# Set to 1 for detailed timer stats in your HTML as comments
	TIMER              => 0,
	# This is your wrapper template located in the 'root/src'
	WRAPPER => 'wrapper.tt2',
 
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
