use utf8;
package Talkalicious::Schema::Result::User;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("users");
__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "username",
  { data_type => "varchar", is_nullable => 0, size => 32 },
  "password",
  { data_type => "varchar", is_nullable => 0, size => 64 },
  "fullname",
  { data_type => "varchar", is_nullable => 1, size => 64 },
  "email",
  { data_type => "varchar", is_nullable => 0, size => 64 },
  "confirmation_key",
  { data_type => "varchar", is_nullable => 1, size => 64 },
  "active",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "registered_on",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 0,
  },
  "logged_in_on",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "comments",
  "Talkalicious::Schema::Result::Comment",
  { "foreign.author_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->has_many(
  "posts",
  "Talkalicious::Schema::Result::Post",
  { "foreign.author_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->has_many(
  "user_preferences",
  "Talkalicious::Schema::Result::UserPreference",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-03-15 13:06:17
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:GUE6y01V8fQhqys3kfsrYA

sub preference_for_name {
  my ($self, $pref_name) = @_;
  return $self->user_preferences->search({preference_name => $pref_name}, {prefetch => 'preference'})->first;
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
