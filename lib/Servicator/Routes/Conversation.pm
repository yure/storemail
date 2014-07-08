package Servicator::Routes::Conversation;
use Dancer ':syntax';

use Dancer::Plugin::Ajax;
use DBI;
use Servicator::Message;
use Dancer::Plugin::DBIC qw(schema resultset rset);


prefix '/:domain';


get '/conversation/all' => sub {
    my @conversations = schema->resultset('Conversation')->search({domain => param('domain')})->all;
    return to_json [map { {$_->get_columns} } @conversations];
};



get '/conversation/:id' => sub {
    my $conversation = schema->resultset('Conversation')->find(param('id')."@".param('domain'));
    
    unless($conversation){
	    $conversation = schema->resultset('Conversation')->create({
	    	id => param('id')."@".param('domain'),
	    	domain => param('domain'),
	    });
    }
    return to_json {
    	id => $conversation->id,
    	subject => $conversation->subject,
    	users => [map { {$_->get_columns} } $conversation->users],
    	messages =>  [map { {$_->get_inflated_columns, attachments => $_->attachments ? [$_->attachments] : []} } $conversation->messages],
    	attachments => $conversation->attachments ? [$conversation->attachments] : [],
    };    	
};


get '/conversation/:id/users' => sub {
    my $conversation = schema->resultset('Conversation')->find(param('id')."@".param('domain'));
    
    unless($conversation){
	    $conversation = schema->resultset('Conversation')->create({
	    	id => param('id')."@".param('domain'),
	    	domain => param('domain'),
	    });
    }
    return to_json {
    	users => [map { {$_->get_columns} } $conversation->users],
    };    	
};


post '/conversation/:id' => sub {
    my $conversation = schema->resultset('Conversation')->find(param('id')."@".param('domain'));
    my $return = 1;
    
    unless($conversation){
	    $conversation = schema->resultset('Conversation')->create({
	    	id => param('id')."@".param('domain'),
	    	domain => param('domain'),
	    });
    }

	# Add user    
    if(param('add_user')){
    	$return = $conversation->add_user( param('email'), param('name') ) ;
    }

	# Remove user    
    if(param('remove_user')){
    	$return = $conversation->remove_user( param('email') ) ;
    }

	# Set subject
    if(param('subject')){
    	return 0 if $conversation->subject;
    	$return = $conversation->subject( param('subject') ) ;
    	$conversation->update;
    }
    
    # Attachments
    
    
    return $return;
};


post '/conversation/:id/message' => sub {
    content_type('application/json');
    my $message = Servicator::Message::new_message(params);
    return to_json {$message->get_inflated_columns};
};


post '/conversation/:id/upload/remove' => sub {
	my $conversation = schema->resultset('Conversation')->find(param('id')."@".param('domain'));
	return $conversation->remove_attachments( param('file') );
};

	
post '/conversation/:id/upload' => sub {
	my $id = param('id');
	my $conversation = schema->resultset('Conversation')->find(param('id')."@".param('domain'));
	my $file = upload('file');
	return $conversation->add_attachments( upload('file') );	
};




true;