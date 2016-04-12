package StoreMail::Message;
use Dancer ':syntax';

our $VERSION = '0.1';

use Dancer::Plugin::DBIC qw(schema resultset rset);
use StoreMail::Email;
use StoreMail::Helper;
use StoreMail::Group;
use Encode;
use Email::MIME;
my $appdir = config->{appdir};


sub new_message{
	my $arg = {@_};

	# Save new message to DB
	my ($name, $email) = extract_email($arg->{from});

    my $message = schema->resultset('Message')->create({
    	domain => $arg->{domain},
    	group_id => $arg->{group_id},
    	group_message_parent_id => $arg->{group_message_parent_id},
    	frm => $email,
    	reply_to => $arg->{reply_to},
    	name => $name,
    	body => $arg->{body},
    	body_type => $arg->{body_type},
    	raw_body => $arg->{raw_body},
    	plain_body => $arg->{plain_body},
    	message_id => $arg->{message_id},
    	source => $arg->{source},
    	batch_id => $arg->{batch_id},
    	subject => decode("MIME-Header", $arg->{subject}),
    	direction => $arg->{direction},
    	date => $arg->{date},
    	'new' => $arg->{'new'} || 1,    	
    	type => $arg->{type} || 'email',
    });

	# Generate msg id
	$message->message_id($message->id_hash) unless $message->message_id;

	# Tracking
	if(domain_setting($message->domain, 'track') or (defined $arg->{track} and $arg->{track} == '1') ){
		add_tracking($message);
	}
    
    # Add recipients
    my @types = ('to', 'cc', 'bcc');
    for my $type (@types){    	
    	for my $p (extract_emails($arg->{$type})){
		    	$message->update_or_create_related('emails', {
		    		email => $p->{email}, 
		    		name => $p->{name}, 
		    		type => $type, 
		    	});
    	}
    	
    }   
    
    # Add tags
    if($arg->{tags}){
	    for my $tag ( split ',', $arg->{tags} ){
	    	my $related = $message->search_related('tags', { value => $tag });
	    	$message->create_related('tags', {value => $tag}) unless $related->count;
	    }
    }
       
    
    # Save POST attachments
    $message->add_attachments(@{$arg->{attachments}}) if $arg->{attachments};

	# Save IMAP attachments
	my $mail_str = $arg->{mail_str};
	if($mail_str){
		my $dir = "$appdir/public/attachments/".$message->attachment_id_dir;
		Email::MIME->new($mail_str)->walk_parts(sub {
			my($part) = @_;
	  		return unless defined $part->content_type and $part->content_type =~ /\bname="([^"]+)"/;  # " grr...
	  		system( "mkdir -p $dir" ) unless (-e $dir); 
			my $name = "$dir/$1";
			#printt "$0: writing $name...\n";
			open my $att_fh, ">", $name or warn "$0: open $name: $!";
			print $att_fh $part->body;
			close $att_fh or warn "$0: close $name: $!";
		});
	}

    # Group
	my $group_send; 
	$group_send = StoreMail::Group::send_group($message) unless $arg->{group_mail_import};
    
    return {message => $message, group_send => $group_send};
}


sub campaing_link_replace {
	my ($p1,$p2,$p3,$campaign_params) = @_;
	if(index($2, '?') > -1){
		return "$p1$p2&$campaign_params$p3\n";
	} 
	else {
		return "$p1$p2?$campaign_params$p3\n";
	}
}

sub add_tracking {
	my $message = shift;
	my $html = $message->body;
	
	my $mid = $message->message_id;	

	# Campaign
	my $batch_name = '';
	$batch_name = $message->batch->name if $message->batch and $message->batch->name;
	if($batch_name){
		my $campaign_params = "utm_source=storemail&utm_medium=email&utm_campaign=$batch_name";
		$html =~ s/( href\=["']?)(.*?)(["'>])/campaing_link_replace($1,$2,$3,$campaign_params)/gie;
	}

	# Tracker
	my $tracker_url = domain_setting($message->domain, 'tracker_url');
	$tracker_url =~ s/\[MID\]/$mid/g;
	$html =~ s/( href\=["']?)(.*?)(["'>])/$1$tracker_url$2$3/gi;
	
	# Tracking pixle
	my $pixle_url = domain_setting($message->domain, 'tracker_pixle');
	$pixle_url =~ s/\[MID\]/$mid/g;
	$html .= "<img src=\"$pixle_url\" height=\"1\" width=\"1\">";
	
	
	$message->body($html);
	1;
}


true;
