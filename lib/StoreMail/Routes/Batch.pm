package StoreMail::Routes::Batch;
use Dancer ':syntax';
our $VERSION = '0.1';

use Dancer::Plugin::Ajax;
use DBI;
use Dancer::Plugin::DBIC qw(schema resultset rset);
use Encode;
use Try::Tiny;

prefix '/:domain';


get '/batch/:id' => sub {
    content_type('application/json');
    my $batch = schema->resultset('Batch')->find({id => param('id')});
    return 'batch not found!' unless $batch;
    return to_json $batch->hash;
};


get '/campaign/:name' => sub {
    content_type('application/json');
    my $batch_list = schema->resultset('Batch')->search({name => param('name')});
    my $batch = $batch_list->next;
    return "Campaign not found" unless $batch;
    my @messages = $batch->campaign_messages;
    
    my $context = {
    	name => param('name'),
    	clicked => [],
    	opened => [],
    	not_opened => [],
    };
    
    for my $message ($batch->campaign_messages->search()->all){
    	if($message->clicks->count){
    		push $context->{clicked}, $message->hash_campaign;
    	}
    	elsif($message->opened){
    		push $context->{opened}, $message->hash_campaign;
    	}
    	else{
    		push $context->{not_opened}, $message->hash_campaign;
    	}
    }
    
    return to_json $context;
};



1;