package StoreMail::Routes::Message;
use Dancer ':syntax';
our $VERSION = '0.1';

use Dancer::Plugin::Ajax;
use DBI;
use Dancer::Plugin::DBIC qw(schema resultset rset);
use Encode;
use Try::Tiny;

prefix '/:domain';
set serializer => 'JSON';


get '/message/unread' => sub {
    content_type('application/json');
    my $messages = schema->resultset('Message')->search(
    	{
    		'new' => 1,  
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


get '/message/:id' => sub {
    content_type('application/json');
    my $message = schema->resultset('Message')->find({id => param('id'), domain => param('domain')});
    return to_json $message->hash;
};


get '/message/:id/tag/set/:tag' => sub {
    content_type('application/json');
    my $message = schema->resultset('Message')->find({id => param('id'), domain => param('domain')});
    my $related = $message->search_related('tags', { value => param('tag') });
    $message->create_related('tags', {value => param('tag')}) unless $related->count;
    return to_json { tags =>  [map { $_->value } $message->tags->all] };  
};


get '/message/:id/tag/remove/:tag' => sub {
    content_type('application/json');
    my $message = schema->resultset('Message')->find({id => param('id'), domain => param('domain')});
    my $related = $message->search_related('tags', { value => param('tag') });
    $message->delete_related('tags', {value => param('tag')}) if $related->count;
    return to_json { tags =>  [map { $_->value } $message->tags->all] };  
};


get '/message/:id/tag/check/:tag' => sub {
    content_type('application/json');
    my $message = schema->resultset('Message')->find({id => param('id'), domain => param('domain')});
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
    my $message;
    try{
	    $message = StoreMail::Message::new_message(							
					direction => 'o',
					send_queue => 1,
					domain => param('domain'),
					%$params
				);
    }
    catch {
    	return to_json {error => $_};
    };
    
    return to_json {success => $message ? 1 : 0};
};


post '/batch/message/send' => sub {
    content_type('application/json');
    
	my $rawparams = param('data');
	my $params = from_json encode('utf8', $rawparams);
    my @emails = split(',', $params->{to});
    my @sent;
    for my $email (@emails){
    	$params->{to} = $email;
	    my $message = StoreMail::Message::new_message(							
					direction => 'o',
					send_queue => 1,
					domain => param('domain'),
					%$params
				);
	    
	    push @sent, $email;
    }
   
    return to_json \@sent;
};


get '/message/:id/read' => sub {
    content_type('application/json');
    
    my $message = schema->resultset('Message')->find({id => param('id'), domain => param('domain')});    
    $message->update({'new' => 0 });
   
    return to_json $message->hash;
};


get '/message/:id/unread' => sub {
    content_type('application/json');
    
    my $message = schema->resultset('Message')->find({id => param('id'), domain => param('domain')});    
    $message->update({'new' => 1 });
   
    return to_json $message->hash;
};

1;