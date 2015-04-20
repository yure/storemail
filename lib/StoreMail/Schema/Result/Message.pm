use utf8;
package StoreMail::Schema::Result::Message;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

StoreMail::Schema::Result::Message

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

use Dancer ':syntax';
use Dancer::Plugin::Email;
use FindBin;
use Cwd qw/realpath/;
use Encode;
use MIME::Base64 qw(encode_base64);
my $appdir = realpath( "$FindBin::Bin/..");


=head1 TABLE: C<message>

=cut

__PACKAGE__->table("message");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 domain

  data_type: 'varchar'
  is_nullable: 1
  size: 90

=head2 conversation_id

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 1
  size: 45

=head2 frm

  data_type: 'varchar'
  is_nullable: 0
  size: 90

=head2 name

  data_type: 'varchar'
  is_nullable: 1
  size: 90

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

=head2 type

  data_type: 'varchar'
  default_value: 'email'
  is_nullable: 0
  size: 45

=head2 message_id

  data_type: 'varchar'
  is_nullable: 1
  size: 36

=head2 source

  data_type: 'varchar'
  is_nullable: 1
  size: 45

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "domain",
  { data_type => "varchar", is_nullable => 1, size => 90 },
  "conversation_id",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 1, size => 45 },
  "frm",
  { data_type => "varchar", is_nullable => 0, size => 90 },
  "name",
  { data_type => "varchar", is_nullable => 1, size => 90 },
  "body",
  { data_type => "text", is_nullable => 1 },
  "plain_body",
  { data_type => "text", is_nullable => 1 },
  "raw_body",
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
  "send_queue",
  { data_type     => "tinyint", is_nullable   => 1, },
  "type",
  {
    data_type => "varchar",
    default_value => "email",
    is_nullable => 0,
    size => 45,
  },
  "body_type",
  {
    data_type => "varchar",
    default_value => "plain",
    is_nullable => 0,
    size => 10,
  },
  "message_id",
  { data_type => "varchar", is_nullable => 1, size => 36 },
  "source",
  { data_type => "varchar", is_nullable => 1, size => 45 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<message_id_UNIQUE>

=over 4

=item * L</message_id>

=back

=cut

__PACKAGE__->add_unique_constraint("message_id_UNIQUE", ["message_id"]);

=head1 RELATIONS

=head2 conversation

Type: belongs_to

Related object: L<StoreMail::Schema::Result::Conversation>

=cut

__PACKAGE__->belongs_to(
  "conversation",
  "StoreMail::Schema::Result::Conversation",
  { id => "conversation_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "SET NULL",
    on_update     => "CASCADE",
  },
);


__PACKAGE__->has_many(
  "emails",
  "StoreMail::Schema::Result::Email",
  { "foreign.message_id" => "self.id" },
  { cascade_copy => 1, cascade_delete => 1 },
);


__PACKAGE__->has_many(
  "tags",
  "StoreMail::Schema::Result::Tag",
  { "foreign.message_id" => "self.id" },
  { cascade_copy => 1, cascade_delete => 1 },
);



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


sub _csv_named_emails {
	my @items = @_;
	return undef unless @items;
	my @named_emails;
	for my $email (@items){
		push @named_emails, $email->named_email; 
	}
	return join(", ", @named_emails);
}

 
sub attachments {
	my ($self) = @_;
	my $id = $self->attachment_id_dir;
	my @files;
	my $dir ="$appdir/public/attachments/$id/";
    opendir(DIR, $dir) or return undef;

    while (my $file = readdir(DIR)) {
    	next if (-d "$dir/$file"); # Skip dirs
        next if ($file =~ m/^\./); # Use a regular expression to ignore files beginning with a period
		push @files, $file;
    }
    closedir(DIR);
    return @files;	
}


sub add_attachments {
	my ($self, @files) = @_;
	my $id = $self->attachment_id_dir;
	
	for my $file (@files){
		my $dir = "$appdir/public/attachments/$id/";
		system( "mkdir -p $dir" ) unless (-e $dir);  
		
		my $content = $file->{content};
		#$content =~ s/data:;base64,//g;
		
		# Remove base64 encoding wrapper
		my $start_tag = ';base64,';
		my $index = index($content, $start_tag);
		my $offset;
		$offset = length($start_tag) + $index unless $index == -1;
		$content = substr($content, $offset);
		
	    my $decoded= MIME::Base64::decode_base64($content);
		open my $fh, '>', "$dir".$file->{name} or die $!;
		binmode $fh;
		print $fh $decoded;
		close $fh
    }
}
 
 
sub attachments_paths {
	my ($self) = @_;
	my $id = $self->attachment_id_dir;
	return map {"$appdir/public/attachments/$id/$_"} $self->attachments;
}


sub attachment_id_dir {
	my ($self) = @_;
	my $id = "".$self->id;
	my $str;
	my @nums = (split //, $id);
	my $odd = 1;
	for my $n (@nums){
		if ($odd){
			$odd = 0;
			$str .= "/$n";		
		}
		else {
			$odd = 1;
			$str .= $n;
		}
	}
	$str = reverse substr $str, 1;
	return $str ;
}


sub send {
	my ($self, $redirect) = @_;
	my $to = $redirect || join(", ", map( $_->email, $self->emails));
	print localtime()."Sending mail to $to from " . $self->frm. ": " . $self->subject.'. ';
	
	my $email = {
		from    => $self->named_from,
		subject => '=?UTF-8?B?'.encode_base64(encode("UTF-8",$self->subject)).'?=',
		body => $self->body || " ",
		type => $self->body_type,
	};
	
	# Redirect if set
	if($redirect){
		$email->{to} = $redirect;
	}
	# Set recievers
	else {
		$email->{to} = _csv_named_emails($self->to) if $self->to;
		$email->{cc} = _csv_named_emails($self->cc) if $self->cc;
		$email->{bcc} = _csv_named_emails($self->bcc) if $self->bcc;
	}
	$email->{attach} = [$self->attachments_paths] if $self->attachments;
	
	my $msg = Dancer::Plugin::Email::email $email;
	if ($msg->{type} and $msg->{type} eq 'failure'){
		warn $msg->{string};
		return 0;
	}		
	print "Sent.\n";
	return 1;
}

sub named_from {
	my $self = shift;
	return encode("MIME-Header", $self->name ? $self->name." <".$self->frm.">" : $self->frm); 
}


sub hash {
	my ($self) = @_;
	return {
		id => $self->id,
		from => $self->frm,
		from_name => $self->name,
    	to => [map({email => $_->email, name => $_->name}, $self->to)],
    	cc => [map({email => $_->email, name => $_->name}, $self->cc)],
    	bcc => [map({email => $_->email, name => $_->name}, $self->bcc)],
    	subject => $self->subject,
    	body => $self->body ,
    	date => $self->date ,
    	attachments => $self->attachments ? [$self->attachments] : [],
    	direction => $self->direction,
    	read => $self->get_column('new') ? 0 : 1,
    	type => $self->type,
    	tags => [map($_->value, $self->tags)],
	}
}
 
1;
