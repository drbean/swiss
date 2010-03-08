package Swiss::Schema::Result::Members;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("InflateColumn::DateTime", "Core");
__PACKAGE__->table("members");
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
  "absent",
  {
    data_type => "BOOL",
    default_value => 'False',
    is_nullable => 0,
    size => undef,
  },
  "firstround",
  {
    data_type => "TINYINT",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("tournament", "player");


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-09-22 15:03:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:gJHWIeNlHGuuGlCZHyMJSQ

__PACKAGE__->belongs_to(
	tournament => 'Swiss::Schema::Result::Tournaments', 'tournament' );
__PACKAGE__->belongs_to( profile=>'Swiss::Schema::Result::Players', 'player' );
__PACKAGE__->has_one( pairingnumber => 'Swiss::Schema::Result::Pairingnumbers',
				{ 'foreign.tournament' => 'self.tournament',
				'foreign.player' => 'self.player' } );
__PACKAGE__->has_one( firstround => 'Swiss::Schema::Result::Firstrounds',
				{ 'foreign.tournament' => 'self.tournament',
				'foreign.player' => 'self.player' } );
__PACKAGE__->has_many( opponent => 'Swiss::Schema::Result::Opponents',
				{ 'foreign.tournament' => 'self.tournament',
				'foreign.player' => 'self.player' } );
__PACKAGE__->has_many( role => 'Swiss::Schema::Result::Roles',
				{ 'foreign.tournament' => 'self.tournament',
				'foreign.player' => 'self.player' } );
__PACKAGE__->has_many( float => 'Swiss::Schema::Result::Floats',
				{ 'foreign.tournament' => 'self.tournament',
				'foreign.player' => 'self.player' } );
__PACKAGE__->has_many( rating => 'Swiss::Schema::Result::Ratings',
				{ 'foreign.tournament' => 'self.tournament',
				'foreign.player' => 'self.player' } );
__PACKAGE__->might_have( score => 'Swiss::Schema::Result::Scores',
				{ 'foreign.tournament' => 'self.tournament',
				'foreign.player' => 'self.player' } );

# You can replace this text with custom content, and it will be preserved on regeneration
1;
