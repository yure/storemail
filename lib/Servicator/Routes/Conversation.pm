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
    	subject => $conversation->subject,
    	users => [map { {$_->get_columns} } $conversation->users],
    	messages =>  [map { {$_->get_inflated_columns} } $conversation->messages],
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
    
    return $return;
};


post '/conversation/:id/message' => sub {
    content_type('application/json');
    return to_json Servicator::Message::new_message(params);
};


true;