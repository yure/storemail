use utf8;
package StoreMail::Schema::Result::Batch;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->table("batch");


__PACKAGE__->add_columns(
  "id" => { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name" => { data_type => "varchar", is_nullable => 1, size => 255 },  
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->has_many(
  "messages",
  "StoreMail::Schema::Result::Message",
  { "foreign.batch_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


1;
