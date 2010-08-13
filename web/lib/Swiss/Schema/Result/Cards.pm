package Swiss::Schema::Result::Cards;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("InflateColumn::DateTime", "Core");
__PACKAGE__->table("cards");
__PACKAGE__->add_columns(
  "tournament",
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
  "table",
  {
    data_type => "TINYINT",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "white",
  {
    data_type => "VARCHAR",
    default_value => undef,
    is_nullable => 0,
    size => 10,
  },
  "black",
  {
    data_type => "VARCHAR",
    default_value => undef,
    is_nullable => 0,
    size => 10,
  },
  "float",
  {
    data_type => "BOOL",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("tournament", "round", "table");


# Not Created by DBIx::Class::Schema::Loader

__PACKAGE__->belongs_to(
	tournament => 'Swiss::Schema::Result::Tournaments', 'tournament' );

1;
