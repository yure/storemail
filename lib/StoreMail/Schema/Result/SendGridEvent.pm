use utf8;
package StoreMail::Schema::Result::SendGridEvent;

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components('InflateColumn::Serializer', 'Core');


__PACKAGE__->table("send_grid_event");


__PACKAGE__->add_columns(
	"id" => { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
	"timestamp" => { data_type => "integer", is_nullable => 1, },
	"sendgrid_id" => { data_type => "varchar", size => 64, is_nullable => 1 },  
	"email" => { data_type => "varchar", size => 255, is_nullable => 1 },  
	"type" => { data_type => "varchar", size => 255, is_nullable => 1 }, 
	"data" => { data_type => "text", is_nullable => 1, serializer_class => 'JSON' },
);

# Timestamps
__PACKAGE__->load_components(qw( TimeStamp ));
__PACKAGE__->add_columns(
  record_created => { data_type => 'datetime', set_on_create => 1 },
  record_updated => { data_type => 'datetime', set_on_create => 1, set_on_update => 1 },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->add_unique_constraint(["sendgrid_id"]);



1;