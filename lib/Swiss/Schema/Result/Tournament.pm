package Swiss::Schema::Result::Tournament;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("InflateColumn::DateTime", "Core");
__PACKAGE__->table("tournament");
__PACKAGE__->add_columns(
  "id",
  {
    data_type => "VARCHAR",
    default_value => undef,
    is_nullable => 0,
    size => 15,
  },
  "arbiter",
  {
    data_type => "VARCHAR",
    default_value => undef,
    is_nullable => 0,
    size => 15,
  },
);
__PACKAGE__->set_primary_key("arbiter");


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-09-22 15:03:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Gy+JKFpLh9KriN3D4enzJw

__PACKAGE__->belongs_to( profile => 'Swiss::Schema::Result::Tournaments',
	'id' );
__PACKAGE__->has_one( round => 'Swiss::Schema::Result::Round', 'tournament' );

# You can replace this text with custom content, and it will be preserved on regeneration
1;
