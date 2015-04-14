use utf8;
package StoreMail::Schema::Result::Tag;

use strict;
use warnings;

use base 'DBIx::Class::Core';


__PACKAGE__->table("tag");


__PACKAGE__->add_columns(
  "message_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "value",
  { data_type => "varchar", is_nullable => 0, size => 90 },  
);


__PACKAGE__->set_primary_key("message_id", "value");


__PACKAGE__->belongs_to(
  "message",
  "StoreMail::Schema::Result::Message",
  { id => "message_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

1;
