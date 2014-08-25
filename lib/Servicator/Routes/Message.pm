package Servicator::Routes::Message;
use Dancer ':syntax';
our $VERSION = '0.1';

use Dancer::Plugin::Ajax;
use DBI;
use Dancer::Plugin::DBIC qw(schema resultset rset);

prefix '/:domain';
set serializer => 'JSON';

get '/message/:id' => sub {
    my $message = schema->resultset('Message')->find(param('id'));
    return to_json {$message->get_columns};
};


post '/message/send' => sub {
    content_type('application/json');
    
	my $params = from_json param('data');
      
    my $message = Servicator::Message::new_message(							
				direction => 'o',
				%$params
			);
    
    $message->send;
    
    # Add attachements and remove them from pending
    # $conversation->attach_all_to( $message->id );
    
    # TODO Send
    # Send email to all recipients
    #Servicator::Email::send_mail( 
    #	sender => $user_sender->name." <".$arg{id}."@".$arg{domain}.">",
    #	recipients => $conversation->recipients($user_sender, {send_copy => $arg{send_copy}}), 
    #	subject => $conversation->subject ? $conversation->subject : $arg{domain}." Message no. ".$arg{id}, 
    #	body => $arg{body},
    #	send_copy => $arg{send_copy},
    #	attachments => $message->attachments_paths,
    #);
    
    return to_json {$message->get_inflated_columns};
};

1;