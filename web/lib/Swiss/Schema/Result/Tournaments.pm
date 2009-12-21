package Swiss::Schema::Result::Tournaments;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("InflateColumn::DateTime", "Core");
__PACKAGE__->table("tournaments");
__PACKAGE__->add_columns(
  "id",
  {
    data_type => "VARCHAR",
    default_value => undef,
    is_nullable => 0,
    size => 15,
  },
  "name",
  {
    data_type => "VARCHAR",
    default_value => undef,
    is_nullable => 0,
    size => 15,
  },
  "description",
  {
    data_type => "VARCHAR",
    default_value => undef,
    is_nullable => 0,
    size => 100,
  },
  "arbiter",
  {
    data_type => "VARCHAR",
    default_value => undef,
    is_nullable => 0,
    size => 15,
  },
  "rounds",
  {
    data_type => "SMALLINT",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-09-22 15:03:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Gy+JKFpLh9KriN3D4enzJw

__PACKAGE__->has_many(
	members => 'Swiss::Schema::Result::Members', 'tournament' );

# You can replace this text with custom content, and it will be preserved on regeneration
1;
