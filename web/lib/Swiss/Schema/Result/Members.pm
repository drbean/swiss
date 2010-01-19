package Swiss::Schema::Result::Members;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("InflateColumn::DateTime", "Core");
__PACKAGE__->table("members");
__PACKAGE__->add_columns(
  "league",
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
);
__PACKAGE__->set_primary_key("league", "player");


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-09-22 15:03:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:gJHWIeNlHGuuGlCZHyMJSQ

#__PACKAGE__->has_many( role => 'Web::Schema::Result::Rolebearers',
#	'foreign.league' => 'self.league', 'foreign.player' => 'self.player'} );
__PACKAGE__->belongs_to( profile => 'Web::Schema::Result::Players', 'player' );
__PACKAGE__->belongs_to( league => 'Web::Schema::Result::Leagues', 'league' );
__PACKAGE__->has_many( play => 'Web::Schema::Result::Play', {
	'foreign.league' => 'self.league', 'foreign.player' => 'self.player'} );

# You can replace this text with custom content, and it will be preserved on regeneration
1;
