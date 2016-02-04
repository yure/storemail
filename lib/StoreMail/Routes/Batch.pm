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
    
    my ($clicked, $opened, $not_opened) = $batch->campaign_groupped_messages;
    
    my $context = {
    	name => param('name'),
    	clicked => $clicked,
    	opened => $opened,
    	not_opened => $not_opened,
    };
    
    return to_json $context;
};



1;