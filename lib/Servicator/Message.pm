package Servicator::Message;
use Dancer ':syntax';

our $VERSION = '0.1';

use Dancer::Plugin::DBIC qw(schema resultset rset);
use Servicator::Email;


sub new_message{
	my %arg = @_;
	my $conversation = schema->resultset('Conversation')->find($arg{id}."@".$arg{domain});

	# Create new conversation if it doesn't exists
    unless($conversation){
	    $conversation = schema->resultset('Conversation')->create({
	    	id => $arg{id}."@".$arg{domain},
	    	domain => $arg{domain},
	    });
    }
    
    # Check sender
	my $user_sender = $conversation->search_related('users', { email => $arg{sender_email}} )->first;
	unless( $user_sender){
		debug "Sender not alowed to send to this conversation";
		return {error => 'Sender not found'} ;
	}
    
	# Save new message to DB
    my $message = schema->resultset('Message')->create({
    	conversation_id => $arg{id}."@".$arg{domain},
    	sender => $user_sender->email,
    	body => $arg{body},
    });
    
    
    # Send email to all recipients
    Servicator::Email::send_mail( 
    	sender => $user_sender->name." <".$arg{id}."@".$arg{domain}.">",
    	recipients => $conversation->recipients($user_sender, {send_copy => $arg{send_copy}}), 
    	subject => $conversation->subject ? $conversation->subject : $arg{domain}." Message no. ".$arg{id}, 
    	body => $arg{body},
    	send_copy => $arg{send_copy},
    );
    
    return $message;
}
    

true;
