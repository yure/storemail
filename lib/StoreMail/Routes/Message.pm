package StoreMail::Routes::Message;
use Dancer ':syntax';
our $VERSION = '0.1';

use Dancer::Plugin::Ajax;
use DBI;
use Encode;
use Try::Tiny;
use StoreMail::Helper;
require StoreMail::Group;
require StoreMail::Message;

prefix '/:domain';
set serializer => 'JSON';


get '/message/unread' => sub {
    content_type('application/json');
    my $messages = schema->resultset('Message')->search(
    	{
    		'new' => 1,
    		internal => 0,  
    		domain => param('domain')  		
    	},
    	{ 
    		order_by => 'date',
    	}
    );
    
    return to_json {
    	messages =>  [map { $_->hash } $messages->all],
    };    	
};


get '/message/incoming' => sub {
    content_type('application/json');
	my $last_id = param('last_id') || return 'No id specified. Example ?last_id=94500';
    my $messages = schema->resultset('Message')->search(
    	{
    		id => {'>' => $last_id},
    		source => {'-not' => undef},  
    		direction => 'i',  
    		internal => 0,
    		domain => param('domain'),	
    	},
    	{ 
    		order_by => 'id',
		rows => 5000,
    	}
    );
    
    return to_json {
    	messages =>  [map { $_->hash_lite } $messages->all],
    };    	
};


get '/message/:id' => sub {
    content_type('application/json');
    my $message = schema->resultset('Message')->find({id => param('id'), domain => param('domain')});
    return 'message not found!' unless $message;
    return to_json $message->hash;
};


get '/message/:hash_id/read' => sub {
    content_type('application/json');
    my $message = schema->resultset('Message')->find({message_id => param('hash_id')});
    return 'message not found!' unless $message;
    unless($message->opened){
    	$message->opened(time);
    	$message->update;
    }
    return 1;
};


get '/message/hash-id/:hash_id' => sub {
    content_type('application/json');
    my $message = schema->resultset('Message')->find({message_id => param('hash_id')});
    return 'message not found!' unless $message;
    my $to = $message->to;
    return to_json {domain => $message->domain, emails => [map {$_->email} $to->all]};
};


get '/message/:id/tag/set/:tag' => sub {
    content_type('application/json');
    my $message = schema->resultset('Message')->find({id => param('id'), domain => param('domain')});
    return 'message not found!' unless $message;
    my $related = $message->search_related('tags', { value => param('tag') });
    $message->create_related('tags', {value => param('tag')}) unless $related->count;
    return to_json { tags =>  [map { $_->value } $message->tags->all] };  
};


get '/message/:id/tag/remove/:tag' => sub {
    content_type('application/json');
    my $message = schema->resultset('Message')->find({id => param('id'), domain => param('domain')});
    return 'message not found!' unless $message;
    my $related = $message->search_related('tags', { value => param('tag') });
    $message->delete_related('tags', {value => param('tag')}) if $related->count;
    return to_json { tags =>  [map { $_->value } $message->tags->all] };  
};


get '/message/:id/tag/check/:tag' => sub {
    content_type('application/json');
    my $message = schema->resultset('Message')->find({id => param('id'), domain => param('domain')});
    return 'message not found!' unless $message;
    my $related = $message->search_related('tags', { value => param('tag') });
    return $related->count ? 1 : 0;
};


get '/message/:id/tag/get_all' => sub {
    content_type('application/json');
    my $message = schema->resultset('Message')->find({id => param('id'), domain => param('domain')});
    return to_json { tags =>  [map { $_->value } $message->tags->all] };
};

 
post '/message/send' => sub {
    content_type('application/json');
    
	my $rawparams = param('data');
	my $params = from_json encode('utf8', $rawparams);
	
	status 406 and return "FROM can't be empty" unless $params->{'from'};
	status 406 and return "TO can't be empty" unless $params->{'to'};
	status 406 and return "SUBJECT can't be empty" unless $params->{'subject'};
	
    my $message;
    my $error_message;
    try{
		# Create
	    my $response = StoreMail::Message::new_message(							
					direction => 'o',
					domain => param('domain'),
					track => param('track'),
					%$params
				);
		$message = $response->{message};
		
		# Send
		if(not param('test')){ # and not $response->{group_send} == 1
			$message->send_queue(1);
	    	$message->update;
		}
    }
    catch {	
    	warn "FAILED TO SEND: " . to_json $params;
    	$error_message = $_;
    };

	if ($error_message){
		status 400;    
	    return $error_message->{msg};
	}

	if (!$message){
		status 400;    
	    return 'Error';
	}
    
    # Message created
    status 201;
    return $message->id;
};


post '/message/:id/clicked' => sub {
    content_type('application/json');
    
    my $message = schema->resultset('Message')->find({message_id => param('id'), domain => param('domain')});    
	return 'message not found!' unless $message;    
    
    my ($protocol, $url_no_protocol) = split( '//', param('url'), 2);
    my ($host_path, $params) = split('\?', $url_no_protocol, 2);
    my ($host, $path) = split('/', $host_path, 2);
    
    $message->add_to_clicks({
    	'date' => param('datetime'), 
    	'url' => param('url'), 
    	'host' => $host, 
    	'path' => $path, 
    	'params' => $params, 
    });
   
	return 1;
};


1;
