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
  is_nullable: 1
  size: 45

=head2 frm

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

=head2 subject

  data_type: 'text'
  is_nullable: 1

=head2 direction

  data_type: 'varchar'
  is_nullable: 0
  size: 1

=head2 new

  accessor: undef
  data_type: 'tinyint'
  default_value: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "conversation_id",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 1, size => 45 },
  "frm",
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
  "subject",
  { data_type => "text", is_nullable => 1 },
  "direction",
  { data_type => "varchar", is_nullable => 0, size => 1 },
  "new",
  {
    accessor      => undef,
    data_type     => "tinyint",
    default_value => 1,
    is_nullable   => 0,
  },
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
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "SET NULL",
    on_update     => "CASCADE",
  },
);

=head2 emails

Type: has_many

Related object: L<Servicator::Schema::Result::Email>

=cut

__PACKAGE__->has_many(
  "emails",
  "Servicator::Schema::Result::Email",
  { "foreign.message_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2014-08-25 14:51:52
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:P2Fyu5DIKnghXCmFAy3Kdg

use Dancer ':syntax';
use Dancer::Plugin::Email;
use FindBin;
use Cwd qw/realpath/;
my $appdir = realpath( "$FindBin::Bin/..");


sub to {
	my ($self) = @_;
	return $self->search_related('emails', { type => 'to' });
}


sub cc {
	my ($self) = @_;
	return $self->search_related('emails', { type => 'cc' });
}


sub bcc {
	my ($self) = @_;
	return $self->search_related('emails', { type => 'bcc' });
}


sub _csv_emails {
	my @items = @_;
	return undef unless @items;
	return join(", ", map( $_->email, @items));
}

 
sub attachments {
	my ($self) = @_;
	my $id = $self->id;
	my @files;
	my $dir ="$appdir/public/attachments/$id/";
    opendir(DIR, $dir) or return undef;

    while (my $file = readdir(DIR)) {
        next if ($file =~ m/^\./); # Use a regular expression to ignore files beginning with a period
		push @files, $file;
    }
    closedir(DIR);
    return @files;	
}


sub add_attachments {
	my ($self, @files) = @_;
	my $id = $self->id;
	
	for my $file (@files){
		my $dir = "$appdir/public/attachments/$id/";
		system( "mkdir -p $dir" ) unless (-e $dir);  
		
		my $content = $file->{content};
		$content =~ s/data:;base64,//g;
	    my $decoded= MIME::Base64::decode_base64($content);
		open my $fh, '>', "$dir".$file->{name} or die $!;
		binmode $fh;
		print $fh $decoded;
		close $fh
    }
}
 
 
sub attachments_paths {
	my ($self) = @_;
	my $id = $self->id;
	return map {"$appdir/public/attachments/$id/$_"} $self->attachments;
}


sub send {
	my ($self) = @_;
	my $to = join(", ", map( $_->email, $self->emails));
	debug "Mail to $to from " . $self->frm. ": " . $self->subject;
	
	my $email = {
		from    => $self->frm,
		subject => $self->subject,
		body => $self->body || " ",
	};
	$email->{to} = _csv_emails($self->to) if _csv_emails($self->to);
	$email->{cc} = _csv_emails($self->cc) if _csv_emails($self->cc);
	$email->{bcc} = _csv_emails($self->bcc) if _csv_emails($self->bcc);
	$email->{attach} = [$self->attachments_paths] if $self->attachments;
	
	my $msg = Dancer::Plugin::Email::email $email;
	warn $msg->{string} if $msg->{type} and $msg->{type} eq 'failure';	
	
	return undef;
}


sub hash {
	my ($self) = @_;
	return {
		id => $self->id,
		from => $self->frm,
    	to => [map($_->email, $self->to)],
    	cc => [map($_->email, $self->cc)],
    	bcc => [map($_->email, $self->bcc)],
    	subject => $self->subject,
    	body => $self->body ,
    	attachments => $self->attachments ? [$self->attachments] : [],
    	direction => $self->direction,
    	read => $self->get_column('new') ? 0 : 1
	}
}
# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
