package Swiss::Schema::Result::Arbiters;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("InflateColumn::DateTime", "Core");
__PACKAGE__->table("arbiters");
__PACKAGE__->add_columns(
  "id",
  {
    data_type => "VARCHAR",
    default_value => undef,
    is_nullable => 0,
    size => 10,
  },
  "name",
  {
    data_type => "VARCHAR",
    default_value => undef,
    is_nullable => 0,
    size => 15,
  },
  "password",
  {
    data_type => "VARCHAR",
    default_value => undef,
    is_nullable => 0,
    size => 50,
  },
);
__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-09-22 15:03:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:d57/qeBCjmLw5JdoWCEnNw

__PACKAGE__->has_many( tournaments => 'Swiss::Schema::Result::Tournaments', 
	'arbiter' );
__PACKAGE__->has_one( active => 'Swiss::Schema::Result::Tournament', 'arbiter');

# You can replace this text with custom content, and it will be preserved on regeneration
1;
