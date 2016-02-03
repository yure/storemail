use utf8;
package StoreMail::Schema::Result::Click;

use strict;
use warnings;

use base 'DBIx::Class::Core';


__PACKAGE__->table("click");


__PACKAGE__->add_columns(
	"id" => { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
	"message_id" => { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
	"date" => { data_type => "datetime", is_nullable => 1, },
	"url" => { data_type => "text", is_nullable => 0 },  
	"host" => { data_type => "varchar", is_nullable => 1 },  
	"path" => { data_type => "varchar", is_nullable => 1 },  
	"params" => { data_type => "varchar", is_nullable => 1 },  
);


__PACKAGE__->set_primary_key("id");


__PACKAGE__->belongs_to(
  "message",
  "StoreMail::Schema::Result::Message",
  { id => "message_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

1;
