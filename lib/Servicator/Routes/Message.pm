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
    return to_json $message->hash;
};


post '/message/send' => sub {
    content_type('application/json');
    
	my $params = from_json param('data');
      
    my $message = Servicator::Message::new_message(							
				direction => 'o',
				%$params
			);
    
    $message->send;
   
    return to_json $message->hash;
};

1;