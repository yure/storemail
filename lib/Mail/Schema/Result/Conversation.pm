use utf8;
package Mail::Schema::Result::Conversation;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Mail::Schema::Result::Conversation

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<conversation>

=cut

__PACKAGE__->table("conversation");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 domain

  data_type: 'varchar'
  is_nullable: 1
  size: 45

=head2 subject

  data_type: 'varchar'
  is_nullable: 1
  size: 45

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "domain",
  { data_type => "varchar", is_nullable => 1, size => 45 },
  "subject",
  { data_type => "varchar", is_nullable => 1, size => 45 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 messages

Type: has_many

Related object: L<Mail::Schema::Result::Message>

=cut

__PACKAGE__->has_many(
  "messages",
  "Mail::Schema::Result::Message",
  { "foreign.conversation_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2014-05-21 10:02:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:MmiUBV7mBLDQvvy4H0BHTg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
