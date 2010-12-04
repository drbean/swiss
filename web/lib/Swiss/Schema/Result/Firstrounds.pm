package Swiss::Schema::Result::Firstrounds;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("InflateColumn::DateTime", "Core");
__PACKAGE__->table("firstrounds");
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
  "firstround",
  {
    data_type => 'TINYINT',
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("tournament", "player");


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-09-22 15:03:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:gJHWIeNlHGuuGlCZHyMJSQ

__PACKAGE__->belongs_to(
	player => 'Swiss::Schema::Result::Members', 
				{ 'foreign.tournament' => 'self.tournament',
				'foreign.player' => 'self.player' } );
__PACKAGE__->belongs_to( profile=>'Swiss::Schema::Result::Players', 'player' );

# You can replace this text with custom content, and it will be preserved on regeneration
1;
