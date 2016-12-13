use utf8;
package StoreMail::Schema::Result::EmailBlacklist;

use strict;
use warnings;

use base 'DBIx::Class::Core';


__PACKAGE__->table("email_blacklist");

__PACKAGE__->add_columns(
  "email" =>  { data_type => "varchar", is_nullable => 0, size => 255 },
  "timestamp" => { data_type => "integer", is_nullable => 0},
  "type" => { data_type => "varchar", is_nullable => 1, size => 255 },
  "reason" => { data_type => "varchar", is_nullable => 1, size => 255 },
);

# Timestamps
__PACKAGE__->load_components(qw( TimeStamp ));
__PACKAGE__->add_columns(
  record_created => { data_type => 'datetime', set_on_create => 1 },
  record_updated => { data_type => 'datetime', set_on_create => 1, set_on_update => 1 },
);


__PACKAGE__->set_primary_key("email");


1;
