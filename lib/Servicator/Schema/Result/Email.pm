use utf8;
package Servicator::Schema::Result::Email;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Servicator::Schema::Result::Email

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<email>

=cut

__PACKAGE__->table("email");

=head1 ACCESSORS

=head2 message_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 email

  data_type: 'varchar'
  is_nullable: 0
  size: 90

=cut

__PACKAGE__->add_columns(
  "message_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "email",
  { data_type => "varchar", is_nullable => 0, size => 90 },
);

=head1 PRIMARY KEY

=over 4

=item * L</message_id>

=item * L</email>

=back

=cut

__PACKAGE__->set_primary_key("message_id", "email");

=head1 RELATIONS

=head2 message

Type: belongs_to

Related object: L<Servicator::Schema::Result::Message>

=cut

__PACKAGE__->belongs_to(
  "message",
  "Servicator::Schema::Result::Message",
  { id => "message_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2014-08-22 08:44:09
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:jLppOtiDSytsqApuZmZnbw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
