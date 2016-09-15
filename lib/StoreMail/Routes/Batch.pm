package StoreMail::Routes::Batch;
use Dancer ':syntax';
our $VERSION = '0.1';

use Dancer::Plugin::Ajax;
use DBI;
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
    my $batch = schema->resultset('Batch')->create({
    	name => $params->{campaign_name},
    	domain => param('domain'),
    });
    $params->{batch_id} = $batch->id;
    
    
    my $error_message;
    try{
	    for my $email (@emails){
		    # Unsubscribe msg
	    	add_unsub_link($params, $email);
	    	
	    	$params->{to} = $email;
	    	
	    	# Create
		    my $response = StoreMail::Message::new_message(							
						direction => 'o',			
						domain => param('domain'),
						%$params
					);
			my $message = $response->{message};		
		    
		    # Send 
		    $message->send_queue(1);
   			$message->update;
		    
		    push @sent, $message->id;
	    }
    }	    
    catch {	
    	warn "FAILED TO SEND: " . to_json $params;
    	$error_message = $_;
    };

	status 400 and return $error_message if $error_message;
	status 400 and return 'Error' unless @sent;
    
   # Messages created
    status 201;
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