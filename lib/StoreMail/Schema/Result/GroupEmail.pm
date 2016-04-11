use utf8;
package StoreMail::Schema::Result::GroupEmail;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

StoreMail::Schema::Result::Email

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<email>

=cut

__PACKAGE__->table("group_email");

=head1 ACCESSORS

=head2 message_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 email

  data_type: 'varchar'
  is_nullable: 0
  size: 90

=head2 type

  data_type: 'varchar'
  default_value: 'to'
  is_nullable: 0
  size: 15

=head2 name

  data_type: 'varchar'
  is_nullable: 1
  size: 90

=cut

__PACKAGE__->add_columns(
  "group_id" => { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "email" => { data_type => "varchar", is_nullable => 0, size => 255 },
  "name" =>{ data_type => "varchar", is_nullable => 1, size => 90 },
  "side" => { data_type => "varchar", is_nullable => 0, size => 15 },
  "can_send" => { data_type     => "tinyint", is_nullable   => 0, default_value => 1 },
  "can_recieve" => { data_type     => "tinyint", is_nullable   => 0, default_value => 1 },
  
);

=head1 PRIMARY KEY

=over 4

=item * L</message_id>

=item * L</email>

=back

=cut

__PACKAGE__->set_primary_key("group_id", "email");

=head1 RELATIONS

=head2 message

Type: belongs_to

Related object: L<StoreMail::Schema::Result::Message>

=cut

__PACKAGE__->belongs_to(
  "group",
  "StoreMail::Schema::Result::Group",
  { id => "group_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2014-08-27 13:19:26
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:eKJ5qBtnQk8TN+CGxvoPMw

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

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
