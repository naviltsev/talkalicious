use utf8;
package Talkalicious::Schema::Result::Post;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("posts");
__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "title",
  { data_type => "text", is_nullable => 0 },
  "excerpt",
  { data_type => "text", is_nullable => 1 },
  "body",
  { data_type => "text", is_nullable => 1 },
  "added_on",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 0,
  },
  "modified_on",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "author_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "published",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "author",
  "Talkalicious::Schema::Result::User",
  { id => "author_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);
__PACKAGE__->has_many(
  "comments",
  "Talkalicious::Schema::Result::Comment",
  { "foreign.post_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-03-15 13:47:33
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ZTGauVRPhpch8bJyPoMZFw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
