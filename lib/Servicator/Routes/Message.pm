package Servicator::Routes::Message;
use Dancer ':syntax';
our $VERSION = '0.1';

use Dancer::Plugin::Ajax;
use DBI;
use Dancer::Plugin::DBIC qw(schema resultset rset);
use Encode;

prefix '/:domain';
set serializer => 'JSON';


get '/message/unread' => sub {
    content_type('application/json');
    my $messages = schema->resultset('Message')->search(
    	{
    		'new' => 1,    		
    	},
    	{ 
    		order_by => 'date',
    	}
    );
    
    return to_json {
    	messages =>  [map { $_->hash } $messages->all],
    };    	
};


get '/message/:id' => sub {
    content_type('application/json');
    my $message = schema->resultset('Message')->find(param('id'));
    return to_json $message->hash;
};


post '/message/send' => sub {
    content_type('application/json');
    
	my $rawparams = param('data');
	my $params = from_json encode('utf8', $rawparams);
      
    my $message = Servicator::Message::new_message(							
				direction => 'o',
				%$params
			);
    
    $message->send;
   
    return to_json $message->hash;
};


get '/message/:id/read' => sub {
    content_type('application/json');
    
    my $message = schema->resultset('Message')->find(param('id'));    
    $message->update({'new' => 0 });
   
    return to_json $message->hash;
};


get '/message/:id/unread' => sub {
    content_type('application/json');
    
    my $message = schema->resultset('Message')->find(param('id'));    
    $message->update({'new' => 1 });
   
    return to_json $message->hash;
};

1;