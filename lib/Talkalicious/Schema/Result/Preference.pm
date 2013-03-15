use utf8;
package Talkalicious::Schema::Result::Preference;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("preferences");
__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "preference_name",
  { data_type => "varchar", is_nullable => 0, size => 32 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "user_preferences",
  "Talkalicious::Schema::Result::UserPreference",
  { "foreign.preference_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-03-15 13:06:17
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:yFd13iJBwgsHM0LaJXhO6A

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
