use utf8;
package StoreMail::Schema::Result::Group;

use strict;
use warnings;

use base 'DBIx::Class::Core';
use StoreMail::Group;


__PACKAGE__->table("message_group");


__PACKAGE__->add_columns(
  id => { data_type => "integer", is_foreign_key => 1, is_nullable => 0, is_auto_increment => 1 },
  domains_id => { data_type => "varchar", is_nullable => 0, size => 90 },  
  domain => { data_type => "varchar", is_nullable => 0, size => 90 },  
  email => { data_type => "varchar", is_nullable => 0, size => 90 },  
  name => { data_type => "varchar", is_nullable => 1, size => 255 },  
);


__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("id_UNIQUE", ["domains_id"]);


__PACKAGE__->has_many(
  "messages",
  "StoreMail::Schema::Result::Message",
  { "foreign.group_id" => "self.id" },
  { cascade_copy => 1, cascade_delete => 1 },
);


__PACKAGE__->has_many(
  "emails",
  "StoreMail::Schema::Result::GroupEmail",
  { "foreign.group_id" => "self.id" },
  { cascade_copy => 1, cascade_delete => 1 },
);

sub email {
	my ($self) = @_;
	return StoreMail::Group::group_email($self->domain, $self->id);	
}


sub hash {
	my ($self) = @_;
	my $hash =  {
		id => $self->domains_id,
		email => $self->email,
		domain => $self->domain,
		name => $self->name,
	};
	
	$hash->{members} = [map {{$_->get_columns}} $self->emails];
	
	return $hash
}

1;