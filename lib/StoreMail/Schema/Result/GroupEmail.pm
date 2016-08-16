use utf8;
package StoreMail::Schema::Result::GroupEmail;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->table("group_email");

__PACKAGE__->add_columns(
  "group_id" => { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "email" => { data_type => "varchar", is_nullable => 0, size => 90 },
  "name" =>{ data_type => "varchar", is_nullable => 1, size => 90 },
  "side" => { data_type => "varchar", is_nullable => 0, size => 15 },
  "can_send" => { data_type     => "tinyint", is_nullable   => 0, default_value => 1 },
  "can_recieve" => { data_type     => "tinyint", is_nullable   => 0, default_value => 1 },
  
);

__PACKAGE__->set_primary_key("group_id", "email");

__PACKAGE__->belongs_to(
  "group",
  "StoreMail::Schema::Result::Group",
  { id => "group_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


use Encode;

use overload
    '""' => 'stringify';
     
    sub stringify {
    my ($self) = @_;
    return $self->email;
}

sub named_email {
	my $self = shift;
	return $self->name ? encode("MIME-Q",$self->name)." <".$self->email.">" : $self->email; 
}

1;
