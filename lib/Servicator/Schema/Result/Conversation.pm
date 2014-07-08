use utf8;
package Servicator::Schema::Result::Conversation;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Servicator::Schema::Result::Conversation

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

Related object: L<Servicator::Schema::Result::Message>

=cut

__PACKAGE__->has_many(
  "messages",
  "Servicator::Schema::Result::Message",
  { "foreign.conversation_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 users

Type: has_many

Related object: L<Servicator::Schema::Result::User>

=cut

__PACKAGE__->has_many(
  "users",
  "Servicator::Schema::Result::User",
  { "foreign.conversation_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2014-05-29 13:09:23
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:9RgV4eapi+tiIgu286Xl7w

use FindBin;
use Cwd qw/realpath/;
my $appdir = realpath( "$FindBin::Bin/..");


sub recipients {
	my ($self, $user_sender, $args) = @_;
	
	my @recipients; 
    for my $user ($self->users){    	
    	push @recipients, {$user->get_columns} unless (!$args->{send_copy} and ($user->email eq $user_sender->email));
    }
	
	return \@recipients;
}


sub add_user {
	my ($self, $email, $name) = @_;
	my $user = $self->search_related('users', { email => $email} );
	return 0 if $user->count;
	
	$self->create_related('users', { email => $email, name => $name});
	return 1;
}


sub remove_user {
	my ($self, $email) = @_;
	my $user = $self->search_related('users', { email => $email} );
	return 0 unless $user->count;
	
	$self->delete_related('users', { email => $email});
	return 1;
}


sub attachments {
	my ($self) = @_;
	my @files;
	my $dir = $appdir.'/attachments/'.$self->id;
    opendir(DIR, $dir) or return undef;

    while (my $file = readdir(DIR)) {
        next if ($file =~ m/^\./); # Use a regular expression to ignore files beginning with a period
		push @files, $file;
    }
    closedir(DIR);
    return @files;
}


sub remove_attachments {
	my ($self, @files) = @_;
	my $count = @files;
	my $success_count = 0;
	# Upload dir
	my $path = "attachments/".$self->id;
	for my $filename (@files){
		unlink "$appdir/$path/$filename";
		$success_count++;
	}
	return $count == $success_count;
}


sub add_attachments {
	my ($self, @files) = @_;
	my $count = @files;
	my $success_count = 0;
	# Upload dir
	my $path = "attachments/".$self->id;
	
	# Upload image
	for my $file (@files){
		my $fileName = $file->{filename};
		
		my $dir = "$appdir/$path/";
		system( "mkdir -p $dir" ) unless (-e $dir);       
		
		if($file->copy_to($dir.$fileName)){			
			$success_count++;
		}		
    }
	return $count == $success_count;
}


sub attach_all_to {
	my ($self, $message_id) = @_;
	my $path = "attachments/".$self->id;
	my $dir = "$appdir/public/attachments/$message_id";
	system( "mkdir -p $dir" ) unless (-e $dir);  
	for my $filename ($self->attachments){
		rename "$appdir/$path/$filename", "$dir/$filename";
	}
}

1;
