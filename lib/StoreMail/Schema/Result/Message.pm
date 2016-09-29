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
use Try::Tiny;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use URI::Escape;
use File::Copy qw(copy);
use StoreMail::Helper;

__PACKAGE__->table("message");

__PACKAGE__->add_columns(
  id => { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  domain  => { data_type => "varchar", is_nullable => 1, size => 255 },
  batch_id => { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  group_id => { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  group_message_parent_id => { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  frm => { data_type => "varchar", is_nullable => 0, size => 255 },
  reply_to => { data_type => "varchar", is_nullable => 1, size => 255 },
  name => { data_type => "varchar", is_nullable => 1, size => 255 },
  body => { data_type => "text", is_nullable => 1 },
  plain_body => { data_type => "text", is_nullable => 1 },
  raw_body => { data_type => "text", is_nullable => 1 },
  date => { data_type => "timestamp", datetime_undef_if_invalid => 1, default_value => \"current_timestamp", is_nullable => 0, },
  subject => { data_type => "text", is_nullable => 1 },
  direction => { data_type => "varchar", is_nullable => 0, size => 1 },
  new => { accessor      => undef, data_type     => "tinyint", default_value => 1, is_nullable   => 0 },
  send_queue => { data_type     => "tinyint", is_nullable   => 1, },
  send_queue_fail_count => { data_type     => "tinyint", is_nullable   => 0, default_value => 0 },
  send_queue_sleep => { data_type     => "integer", is_nullable   => 0, default_value => 0 },
  type => { data_type => "varchar", default_value => "email", is_nullable => 0, size => 255 },
  body_type => { data_type => "varchar", default_value => "plain", is_nullable => 0, size => 255 },
  message_id => { data_type => "varchar", is_nullable => 1, size => 255 },
  header_message_id => { data_type => "text", is_nullable => 1 },
  source => { data_type => "varchar", is_nullable => 1, size => 255 },
  sent => { data_type => "integer", is_nullable   => 1, },
  opened => { data_type => "integer", is_nullable   => 1, },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->add_unique_constraint("message_id_UNIQUE", ["message_id"]);

__PACKAGE__->belongs_to(
  "group_message_parent",
  "StoreMail::Schema::Result::Message",
  { id => "group_message_parent_id" },
  { is_deferrable => 1, on_delete => "SET NULL", on_update => "SET NULL" },
);

__PACKAGE__->belongs_to(
  "batch",
  "StoreMail::Schema::Result::Batch",
  { id => "batch_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "SET NULL",
    on_update     => "CASCADE",
  },
);


__PACKAGE__->has_many(
  "group_message_children",
  "StoreMail::Schema::Result::Message",
  { "foreign.group_message_parent_id" => "self.id" },
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


__PACKAGE__->has_many(
  "clicks",
  "StoreMail::Schema::Result::Click",
  { "foreign.message_id" => "self.id" },
  { cascade_copy => 1, cascade_delete => 1 },
);

__PACKAGE__->belongs_to(
  "group",
  "StoreMail::Schema::Result::Group",
  { id => "group_id" },
  { is_deferrable => 1, on_delete => "SET NULL", on_update => "SET NULL" },
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

sub toccbcc {
	my ($self) = @_;
	return $self->emails;
}

sub toccbcc_hash {
	my ($self) = @_;
	my $hash = {};
	for my $email ($self->emails){
		$hash->{$email->type} ||= [];
		push $hash->{$email->type}, {email => $email->email, name => $email->name};
	}
	return %$hash;
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
	my $self = shift; 
	my $files = {};
	for my $file ($self->id_attachments, $self->hash_attachments){
		$files->{$file} = 1;		
	}
    return keys %$files;	
}

 
sub id_attachments { my $self = shift; return files_in_dir(local_root_path($self->attachment_id_path)); }
sub hash_attachments { my $self = shift; return files_in_dir(local_root_path($self->attachment_hash_path)); }


sub attachment_links {
	my $self = shift;
	my $hash_path = $self->attachment_hash_path;
	my $public_url = domain_setting($self->domain, 'public_url');
	return [
		map {{	
			filename => decode('UTF-8',$_),	
			full_link => "$public_url/$hash_path/" . uri_escape($_) ,
			link => "/$hash_path/" . uri_escape($_) ,
		}} $self->attachments
	]
}


sub add_attachments {
	my ($self, @files) = @_;
	
	for my $file (@files){
		my $dir = local_root_path $self->attachment_hash_path;
		system( "mkdir -p $dir" ) unless (-e $dir);  
		
		my $content = $file->{content};
		my $filename = $file->{name};
		
		# Remove base64 encoding wrapper
		my $start_tag = ';base64,';
		my $index = index($content, $start_tag);
		my $offset;
		$offset = length($start_tag) + $index unless $index == -1;
		$content = substr($content, $offset) if $offset;
		
	    my $decoded= MIME::Base64::decode_base64($content);
		open my $fh, '>', "$dir/$filename" or die $!;
		binmode $fh;
		print $fh $decoded;
		close $fh
    }
}
 
 
sub copy_attachments {
	my ($self, $message) = @_;
	my @files = $message->attachments;
	return 0 unless @files;
	my $to_dir = local_root_path $self->attachment_hash_path;
	system( "mkdir -p $to_dir" ) unless (-e $to_dir);  
	my $count = 0;
	for my $file (@files){
		next unless $file;
		my $from = local_root_path $message->attachment_local_path($file);
		my $to = "$to_dir/$file";
		copy "$from", "$to";		
    }
    return $count;
}
 
 
sub attachments_local_root_paths {
	my ($self) = @_;
	my @paths;	
	for my $att ($self->attachments){
		push @paths, local_root_path $self->attachment_local_path($att);
	}
	return \@paths;
}

 
 
sub attachment_local_path {
	my ($self, $file) = @_;
	
	my $file_path;    
    # New path
    my $hash_path = $self->attachment_hash_path;
    $file_path = "$hash_path/$file";
    return $file_path if file_exists $file_path;

    # Old path
    my $path_id = $self->attachment_id_path;
    $file_path = "$path_id/$file";
   	return $file_path if file_exists $file_path;
	return "";
}


sub attachment_id_path {
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
	return "attachments/$str" ;
}


sub attachment_hash_path {
	my ($self) = @_;
	
	$self->message_id($self->id_hash) and $self->update unless $self->message_id;
	my @hash_chunks = ( $self->message_id =~ m/../g );
	my $hash_path = join '/', @hash_chunks;
	my $hash_check = $self->id_hash_two_pass;
		
	return "file/$hash_path/$hash_check" ;
}


sub send {
	my ($self, $redirect) = @_;
	my $to = $redirect || join(", ", map( $_->email, $self->emails));
	
	my $email = {
		from    => $self->named_from,
		subject => '=?UTF-8?B?'.encode_base64(encode("UTF-8",$self->subject)).'?=',
		body => encode("UTF-8",$self->body) || " ",
		type => $self->body_type,
		'reply-to' => $self->reply_to,
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
	$email->{attach} = $self->attachments_local_root_paths if $self->attachments;
	
	unless($email->{to}){		
		return 0, 'No reciepients, cannot send.';
	}
	
	try{
		my $msg = Dancer::Plugin::Email::email $email;
		if ($msg->{type} and $msg->{type} eq 'failure'){
			return 0, $msg->{string};
		}		
		return 1, "Sent";
	} 
	catch {
		
		return 0, 'FAILURE. '. to_json($email) .' '.$_;
	};
}

sub named_from {
	my $self = shift;
	return  $self->name ? encode("MIME-Q",$self->name)." <".$self->frm.">" : $self->frm; 
}


sub name_or_email {
	my $self = shift;
	return  $self->name ? $self->name : $self->frm; 
}


sub hash {
	my ($self, $args) = @_;
	
	my $clean_body = body_cleanup($args->{plain} ? $self->plain_body : $self->body);
	
	return {
		id => $self->id,
		from => $self->frm,
		reply_to => $self->reply_to,
		from_name => $self->name,
    	$self->toccbcc_hash,
    	subject => $self->subject,
    	body => $clean_body,
    	date => $self->date ,
    	attachments => $self->attachments ? $self->attachment_links : [],
    	direction => $self->direction,
    	new => $self->get_column('new') ? 0 : 1,
    	type => $self->type,
    	send_queue => $self->send_queue ? 1 : 0,
    	send_queue_fail_count => $self->send_queue_fail_count,
    	type => $self->type,
    	tags => [map($_->value, $self->tags)],
    	opened => $self->opened,
    	sent => $self->sent,
	}
}


sub hash_lite {
	my ($self) = @_;
	return {
		from => $self->frm,
    	to => [map {$_->email} $self->to],
    	date => $self->date ,
    	id => $self->id ,
    	group_id => $self->group_id ,
    	tags => [map($_->value, $self->tags)],
	}
}


sub hash_campaign {
	my ($self) = @_;
	my $hash = {
		from => $self->frm,
    	to => [map {$_->email} $self->to],
    	date => $self->date ,
    	id => $self->id ,
    	opened => $self->opened,
	};
    
    $hash->{clicks} = [map($_->url, $self->clicks)] if $self->clicks->count;
	
	return $hash
}
 
sub id_hash {
	my ($self) = @_;
	return md5_hex($self->id . config->{salt});
}
 
sub id_hash_two_pass {
	my ($self) = @_;
	return md5_hex($self->id_hash. substr(config->{salt}, 0, 3) . $self->id_hash);
}
 
 
sub make_copy {
	my ($self) = @_;
	my $schema = $self->result_source->schema; 
	$self->id(undef);	
	$self->message_id(undef);	
	my $msg = $schema->resultset('Message')->create( $self->{_column_data} );
	$msg->message_id($msg->id_hash);	
	return $msg;
}
 

sub body_cleanup {
	my ($body) = @_;	
	return undef unless $body;
	
	# Extract body content - removed: Some emails are mixed with some plain text before body
	# $body =~ /<body[^>]*>(.*)<\/body>/smgi; # Remove style tag
	# $body = $1 if $1;
	
	$body =~ s/<style(.+?)<\/style>//smgi; # Remove style tag
	$body =~ s/<script(.+?)<\/script>//smgi; # Remove script tags
	$body =~ s/<script(.+?)>//smgi; # Empty opening body
	$body =~ s/<script(.+?)>//smgi; # Remove scripts
	$body =~ s/<base(.+?)>//smgi; # Remove <base>
	$body =~ s/<img(.+?)>//smgi; # Remove images
	return $body;
}
 
1;
