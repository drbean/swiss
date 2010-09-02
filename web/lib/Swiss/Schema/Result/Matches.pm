package Swiss::Schema::Result::Matches;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("InflateColumn::DateTime", "Core");
__PACKAGE__->table("matches");
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
  "pair",
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
  # if there was a bye, white gets the bye, and black is 'Bye'.
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
  # possible values are 'White', 'Black', 'Draw,' 'None' or 'Unknown'.
  "win",
  {
    data_type => "VARCHAR",
    default_value => undef,
    is_nullable => 0,
    size => 10,
  },
  # possible values are 'White', 'Black', 'Both', 'None' or 'Unknown'.
  "forfeit",
  {
    data_type => "VARCHAR",
    default_value => undef,
    is_nullable => 0,
    size => 10,
  },
  # possible values are 'White', 'Black', 'Both', 'None' or 'Unknown'.
  "tardy",
  {
    data_type => "VARCHAR",
    default_value => undef,
    is_nullable => 0,
    size => 10,
  },
);
__PACKAGE__->set_primary_key("tournament", "round", "pair");


# Not Created by DBIx::Class::Schema::Loader

1;
