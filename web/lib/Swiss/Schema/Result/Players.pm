package Swiss::Schema::Result::Players;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("InflateColumn::DateTime", "Core");
__PACKAGE__->table("players");
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
    size => 20,
  },
);
__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-09-22 15:03:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:d57/qeBCjmLw5JdoWCEnNw

__PACKAGE__->has_many(
	memberships => 'Swiss::Schema::Result::Members', 'player');
__PACKAGE__->has_many(
	opponent => 'Swiss::Schema::Result::Opponents', 'player');
__PACKAGE__->has_many(
	role => 'Swiss::Schema::Result::Roles', 'player');
__PACKAGE__->has_many(
	score => 'Swiss::Schema::Result::Scores', 'player');
__PACKAGE__->has_many(
	rating => 'Swiss::Schema::Result::Ratings', 'player');

# You can replace this text with custom content, and it will be preserved on regeneration
1;
