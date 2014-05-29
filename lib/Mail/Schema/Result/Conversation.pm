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

  data_type: 'varchar'
  is_nullable: 0
  size: 45

=head2 domain

  data_type: 'varchar'
  is_nullable: 1
  size: 45

=head2 subject

  data_type: 'varchar'
  is_nullable: 1
  size: 45

=head2 date

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "varchar", is_nullable => 0, size => 45 },
  "domain",
  { data_type => "varchar", is_nullable => 1, size => 45 },
  "subject",
  { data_type => "varchar", is_nullable => 1, size => 45 },
  "date",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 0,
  },
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

=head2 users

Type: has_many

Related object: L<Mail::Schema::Result::User>

=cut

__PACKAGE__->has_many(
  "users",
  "Mail::Schema::Result::User",
  { "foreign.conversation_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2014-05-28 11:40:35
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:IuaazjlKzQBtsA8oC0L0sA


sub add_user {
	my ($self, $email, $name) = @_;
	my $user = $self->search_related('users', { email => $email} );
	return 0 if $user->count;
	
	$self->create_related('users', { email => $email, name => $name});
	return 1;
}


sub recipients {
	my ($self, $user_sender, $args) = @_;
	
	my @recipients; 
    for my $user ($self->users){    	
    	push @recipients, {$user->get_columns} unless (!$args->{send_copy} and ($user->email eq $user_sender->email));
    }
	
	return \@recipients;
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
