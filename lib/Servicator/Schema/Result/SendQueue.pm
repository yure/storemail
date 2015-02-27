use utf8;
package Servicator::Schema::Result::SendQueue;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Servicator::Schema::Result::GmailFetch

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<gmail_fetch>

=cut

__PACKAGE__->table("send_queue");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_nullable: 0

=head2 username

  data_type: 'varchar'
  is_nullable: 0
  size: 45

=head2 timestamp

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 1

=head2 mail_epoch

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_nullable => 0 },  
  "timestamp",
  {
    data_type => "timestamp",
    default_value => \"current_timestamp",
    is_nullable => 0,
  },  
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=item * L</username>

=back

=cut

__PACKAGE__->set_primary_key("id", "timestamp");


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2015-01-13 13:19:16
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:W3hjGwfXoSg2cR+URfwPWg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
