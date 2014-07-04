use utf8;
package Servicator::Schema::Result::Message;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Servicator::Schema::Result::Message

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<message>

=cut

__PACKAGE__->table("message");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 conversation_id

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 0
  size: 45

=head2 sender

  data_type: 'varchar'
  is_nullable: 0
  size: 45

=head2 body

  data_type: 'text'
  is_nullable: 1

=head2 date

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

=head2 sender_email

  data_type: 'varchar'
  is_nullable: 1
  size: 45

=head2 recipients

  data_type: 'text'
  is_nullable: 1

=head2 attachments

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "conversation_id",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 0, size => 45 },
  "sender",
  { data_type => "varchar", is_nullable => 0, size => 45 },
  "body",
  { data_type => "text", is_nullable => 1 },
  "date",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 0,
  },
  "sender_email",
  { data_type => "varchar", is_nullable => 1, size => 45 },
  "recipients",
  { data_type => "text", is_nullable => 1 },
  "attachments",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 conversation

Type: belongs_to

Related object: L<Servicator::Schema::Result::Conversation>

=cut

__PACKAGE__->belongs_to(
  "conversation",
  "Servicator::Schema::Result::Conversation",
  { id => "conversation_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2014-07-04 14:10:46
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:obuHDzryM1fhvJZheKD6mw


__PACKAGE__->inflate_column(
	attachments => {
     	inflate => sub { [split('/', shift)] },
    	deflate => sub { 
	     	my $attachments = shift;
	     	return join('/',@{ $attachments });
	    },
 	}
 );

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
