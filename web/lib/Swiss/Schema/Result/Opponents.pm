package Swiss::Schema::Result::Opponents;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("InflateColumn::DateTime", "Core");
__PACKAGE__->table("opponents");
__PACKAGE__->add_columns(
  "tournament",
  {
    data_type => "VARCHAR",
    default_value => undef,
    is_nullable => 0,
    size => 15,
  },
  "player",
  {
    data_type => "VARCHAR",
    default_value => undef,
    is_nullable => 0,
    size => 10,
  },
  "opponent",
  {
    data_type => "VARCHAR",
    default_value => undef,
    is_nullable => 0,
    size => 15,
  },
  "round",
  {
    data_type => "TINYINT",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("tournament", "player", "round");


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-09-22 15:03:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:gJHWIeNlHGuuGlCZHyMJSQ

__PACKAGE__->belongs_to(
	tournament => 'Swiss::Schema::Result::Tournaments', 'tournament' );
__PACKAGE__->belongs_to( ego =>'Swiss::Schema::Result::Players', 'player' );
__PACKAGE__->belongs_to( other =>'Swiss::Schema::Result::Players', 'opponent' );

# You can replace this text with custom content, and it will be preserved on regeneration
1;
