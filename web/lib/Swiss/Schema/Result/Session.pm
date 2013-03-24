package Swiss::Schema::Result::Session;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("sessions");
__PACKAGE__->add_columns(
  "id",
  { data_type => "CHAR", is_nullable => 0, size => 72 },
  "session_data",
  { data_type => "VARCHAR", is_nullable => 1, size => 7500 },
  "expires",
  { data_type => "INT", is_nullable => 1, size => undef },
);
__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2008-08-26 18:19:13
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:qZV4TVWeGplwW97FrfZNiA

=head1 NAME

DB::Session - A model object to store session data with Catalyst;:Plugin::      +Session::Store::DBIC instead of FastMmap or File

=head1 DESCRIPTION

This is an object that represents a row in the 'sessions' table.

=cut
# You can replace this text with custom content, and it will be preserved on regeneration
1;
