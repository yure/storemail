package StoreMail::Message;
use Dancer ':syntax';

our $VERSION = '0.1';

use Dancer::Plugin::DBIC qw(schema resultset rset);
use StoreMail::Email;
use StoreMail::Helper;;
use Encode;

sub new_message{
	my (%arg) = @_;

	my $conversation_id = $arg{id} and $arg{domain} ? $arg{id}."@".$arg{domain} : undef;
	my ($name, $email) = extract_email($arg{from});


	# Save new message to DB
    my $message = schema->resultset('Message')->create({
    	conversation_id => $conversation_id,
    	domain => $arg{domain},
    	frm => $email,
    	name => $name,
    	body => $arg{body},
    	body_type => $arg{body_type},
    	raw_body => $arg{raw_body},
    	plain_body => $arg{plain_body},
    	message_id => $arg{message_id},
    	source => $arg{source},
    	batch_id => $arg{batch_id},
    	subject => decode("MIME-Header", $arg{subject}),
    	direction => $arg{direction},
    	date => $arg{date},
    	'new' => $arg{'new'} || 1,    	
    	type => $arg{type} || 'email',
    });

	# Tracking
	if(domain_setting($message->domain, 'track') or (defined $arg{track} and $arg{track} == '1') ){
		add_tracking($message);
	}
    
    # Add recipients
    my @types = ('to', 'cc', 'bcc');
    for my $type (@types){
    	next unless $arg{$type};
	    $arg{$type} = [$arg{$type}] unless ref $arg{$type} eq 'ARRAY';
	    for my $raw_emails ( @{$arg{$type}} ){
		    for my $raw_email ( split ',', $raw_emails ){
		    	my ($name, $email) = extract_email($raw_email);
		    	$message->update_or_create_related('emails', {
		    		email => $email, 
		    		name => $name, 
		    		type => $type, 
		    	});
		    }
	    }
    }   
    
    # Add tags
    if($arg{tags}){
	    for my $tag ( split ',', $arg{tags} ){
	    	my $related = $message->search_related('tags', { value => $tag });
	    	$message->create_related('tags', {value => $tag}) unless $related->count;
	    }
    }
       
    
    # Save attachments
   $message->add_attachments(@{$arg{attachments}}) if $arg{attachments};
    $message->send_queue($arg{send_queue});
    $message->update;
    return $message;
}


sub add_tracking {
	my $message = shift;
	my $html = $message->body;
	
	my $mid = $message->message_id;
	unless($mid){
		$mid = $message->id_hash;
		$message->message_id($mid);
	} 

	# Campaign
	my $batch_name = '';
	$batch_name = $message->batch->name if $message->batch and $message->batch->name;
	if($batch_name){
		my $campaign_params = "?utm_source=storemail&utm_medium=email&utm_campaign=$batch_name";
		$html =~ s/( href\=["']?)(.*?)(["'>])/$1$2$campaign_params$3/gi;
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


sub extract_email {
	my $str = shift;
	$str = decode("MIME-Header", $str);
	my ($name, $email) = $str =~ /(.*?)<(.*?)>/s;
	$email = $str unless $email;
	$name = trim($name);
	$name = undef if defined $name and $name eq '';
	return (trim($name), trim($email));
}

true;
