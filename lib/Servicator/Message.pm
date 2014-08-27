package Servicator::Message;
use Dancer ':syntax';

our $VERSION = '0.1';

use Dancer::Plugin::DBIC qw(schema resultset rset);
use Servicator::Email;
use Encode;

sub new_message{
	my (%arg) = @_;

	my $conversation_id = $arg{id} and $arg{domain} ? $arg{id}."@".$arg{domain} : undef;
	my ($email, $name) = extract_email($arg{from});

	# Save new message to DB
    my $message = schema->resultset('Message')->create({
    	conversation_id => $conversation_id,
    	frm => $email,
    	name => $name,
    	body => $arg{body},
    	subject => decode("MIME-Header", $arg{subject}),
    	direction => $arg{direction},
    	date => $arg{date},
    	'new' => $arg{'new'} || 1,
    	type => $arg{type} || 'email',
    });
    
    # Add recipients
    my @types = ('to', 'cc', 'bcc');
    for my $type (@types){
    	next unless $arg{$type};
	    $arg{$type} = [$arg{$type}] unless ref $arg{$type} eq 'ARRAY';
	    for my $raw_emails ( @{$arg{$type}} ){
		    for my $raw_email ( split ',', $raw_emails ){
		    	my ($email, $name) = extract_email($raw_email);
		    	$message->add_to_emails({
		    		email => $email, 
		    		name => $name, 
		    		type => $type, 
		    	});
		    }
	    }
    }   
    
    # Save attachments
   $message->add_attachments(@{$arg{attachments}}) if $arg{attachments};
    
    return $message;
}


sub extract_email {
	my $str = shift;
	$str = decode("MIME-Header", $str);
	my ($name, $email) = $str =~ /(.*?)<(.*?)>/s;
	$email = $str unless $email;
	return (trim($email), trim($name));
}

    
sub trim {
	my $str = shift;
	$str =~ s/^\s+|\s+$//g;
	return $str;
}

true;
