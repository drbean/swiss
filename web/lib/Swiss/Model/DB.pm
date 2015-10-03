package Swiss::Model::DB;

use strict;
use base 'Catalyst::Model::DBIC::Schema';

use Catalyst;
use Swiss;

my $name = Swiss->config->{database};
# my $name = 'swiss041';

my $connect_info;
if ( $^O eq 'linux' ) { $connect_info = [ "dbi:Pg:dbname=$name", '', '', ]; }

__PACKAGE__->config(
    schema_class => 'Swiss::Schema',
    connect_info =>  $connect_info,
		        # connect_info => ['dbi:SQLite:db/demo','','']
);

=head1 NAME

Web::Model::DB - Catalyst DBIC Schema Model

=head1 SYNOPSIS

See L<Web>

=head1 DESCRIPTION

L<Catalyst::Model::DBIC::Schema> Model using schema L<Web::Schema>

=head1 GENERATED BY

Catalyst::Helper::Model::DBIC::Schema - 0.29

=head1 AUTHOR

Dr Bean

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
