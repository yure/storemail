package Servicator::Message;
use Dancer ':syntax';

our $VERSION = '0.1';

use Dancer::Plugin::DBIC qw(schema resultset rset);
use Servicator::Email;


sub new_message{
	my (%arg) = @_;

	my $conversation_id = $arg{id} and $arg{domain} ? $arg{id}."@".$arg{domain} : undef;

	# Save new message to DB
    my $message = schema->resultset('Message')->create({
    	conversation_id => $conversation_id,
    	frm => extract_email($arg{from}),
    	body => $arg{body},
    	subject => $arg{subject},
    	direction => $arg{direction},
    	date => $arg{date},
    	'new' => $arg{'new'} || 1,
    	type => $arg{type},
    });
    
    # Add recipients
    my @types = ('to', 'cc', 'bcc');
    for my $type (@types){
    	next unless $arg{$type};
	    $arg{$type} = [$arg{$type}] unless ref $arg{$type} eq 'ARRAY';
	    for my $raw_email ( @{$arg{$type}} ){
	    	$message->add_to_emails({email => extract_email($raw_email), type => $type });
	    }
    }   
    
    # Save attachments
   $message->add_attachments(@{$arg{attachments}}) if $arg{attachments};
    
    return $message;
}


sub extract_email {
	my $str = shift;
	my ($email) = $str =~ /<(.*?)>/s;	
	return trim($email ? $email : $str);
}

    
sub trim {
	my $str = shift;
	$str =~ s/^\s+|\s+$//g;
	return $str;
}

true;
