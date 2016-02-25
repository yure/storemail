package StoreMail::Routes::Batch;
use Dancer ':syntax';
our $VERSION = '0.1';

use Dancer::Plugin::Ajax;
use DBI;
use Dancer::Plugin::DBIC qw(schema resultset rset);
use Encode;
use Try::Tiny;
use MIME::Base64;
use StoreMail::Helper;

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


post '/batch/message/send' => sub {
    content_type('application/json');
    
	my $rawparams = param('data');
	my $params = from_json encode('utf8', $rawparams);
    my @emails = split(',', $params->{to});
    my @sent;
    
    # Batch 
    my $batch = schema->resultset('Batch')->create({name => $params->{campaign_name}});
    $params->{batch_id} = $batch->id;
    
    
    
    for my $email (@emails){
	    # Unsubscribe msg
    	add_unsub_link($params, $email);
    	
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


sub add_unsub_link {
	my ($params, $email) = @_;
	my $unsub_text = $params->{unsub_text};
	return undef unless $unsub_text;
	delete $params->{unsub_text};
	my $unsub_url = domain_setting(param('domain'), 'unsub_url');	
	my $enc_email = encode_base64($email);
	chomp $enc_email;
	$unsub_text =~ s/\[\[\[(.*)\]\]\]/<a href="$unsub_url$enc_email">$1<\/a>/g;
	$params->{body} .= "<div style=\"font-size: 10px;\">$unsub_text<div>";
	return 1;
} 
1;