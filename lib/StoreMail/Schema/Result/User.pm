use utf8;
package StoreMail::Schema::Result::User;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

StoreMail::Schema::Result::User

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<user>

=cut

__PACKAGE__->table("user");

=head1 ACCESSORS

=head2 conversation_id

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 0
  size: 45

=head2 email

  data_type: 'varchar'
  is_nullable: 0
  size: 90

=head2 name

  data_type: 'varchar'
  is_nullable: 1
  size: 45

=cut

__PACKAGE__->add_columns(
  "conversation_id",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 0, size => 45 },
  "email",
  { data_type => "varchar", is_nullable => 0, size => 90 },
  "name",
  { data_type => "varchar", is_nullable => 1, size => 45 },
);

=head1 PRIMARY KEY

=over 4

=item * L</conversation_id>

=item * L</email>

=back

=cut

__PACKAGE__->set_primary_key("conversation_id", "email");

=head1 RELATIONS

=head2 conversation

Type: belongs_to

Related object: L<StoreMail::Schema::Result::Conversation>

=cut

__PACKAGE__->belongs_to(
  "conversation",
  "StoreMail::Schema::Result::Conversation",
  { id => "conversation_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2014-05-29 13:09:23
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Js+zvchR4YDaeI33uqs7XQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
