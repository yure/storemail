package StoreMail::Routes::SMS;
use Dancer ':syntax';
our $VERSION = '0.1';

use StoreMail::Helper;
use StoreMail::SMS;
use Encode;
use Try::Tiny;
use DateTime::Format::MySQL;

prefix '/:domain/sms';
set serializer => 'JSON';

 
post '/send' => sub {
    content_type('application/json');
    
	my $params = params('body');
	my $request = request;
	# Required fields
	status 406 and return "FROM can't be empty" unless $params->{'from'};
	status 406 and return "TO can't be empty" unless $params->{'to'};
	status 406 and return "BODY can't be empty" unless $params->{'body'};
	
	# Phone number format
	my $from = extract_phone $params->{'from'};
	my $to = extract_phone $params->{'to'};

	# Valid nums
	status 406 and return "Invalid TO number" if length $to < 3 or length $to > 15;
	status 406 and return "Invalid FROM number" if length$from < 3 or length $from > 15;
	
	my $number_config = config->{phone_numbers}->{$from};
	my $port = $number_config->{port} or status 403 and return "Not allowed to send from $from";
	
	
	# Body length
	my $sms_length_limit = config->{sms_length_limit} || 160;
	status 406 and return "BODY too long (".length($params->{'body'})."). Max $sms_length_limit chars. Body: ".$params->{'body'} if length($params->{'body'}) > $sms_length_limit;
	
    my $sms;
    my $error_message;
    my $created = DateTime::Format::MySQL->format_datetime(DateTime->now);
    try{
		# Create
	    $sms = schema->resultset('SMS')->create({
			direction => 'o',
			domain => param('domain'),			
			frm => $from, 
			to => $to, 
			body => $params->{body}, 
			created => $created,
			send_timestamp => $created,
	    });
		
		# Add to queue if not test
		if($sms and !$params->{test}){
			$sms->send_queue(1);
	    	$sms->update;
		}
		
    }
    catch {	
    	warn "FAILED TO SEND: " . to_json $params;
    	$error_message = $_;
    };

	status 400; return $error_message->{msg} if $error_message;	
	status 400; return 'Error' unless $sms;
    
    # Message created
    status 201;
    return $sms->id;
};


get '/messages/:comma_separated_phone_numbers' => sub {
	content_type('application/json');
	
	return to_json {error => 'No phone numbers specified'} if (length (param('comma_separated_phone_numbers')) < 0);
	
	my @numbers = map { $_ } split ',', param('comma_separated_phone_numbers');
	
	# Remove duplicates / yes, this happens
	my %hash   = map { extract_phone($_) => 1 } @numbers;
   	@numbers = keys %hash;

	my $options = {order_by => {'-desc' => 'send_timestamp'}};
	
	# Limit
	$options->{rows} = param('limit') if param('limit');
	
	my $where = {
		domain => param('domain'),
		'-or' => [
			frm => {'-in' => \@numbers},
			to => {'-in' => \@numbers},
		]
	};
	
	# Direction
	$where->{direction} = param('direction') if param('direction');
	
    	
	# Date span
	my $from =  param('from');
	my $to =  param('to');
	#my $parser   = schema->storage->datetime_parser;	
    $where->{-and} ||= [] and push $where->{-and}, {created => { '<=', $to }} if $to;
    $where->{-and} ||= [] and push $where->{-and}, {created => { '>=', $from }} if $from;

    my $messages = schema->resultset('SMS')->search(
    	$where,
    	$options,
    );
    
    my $message_hashes = [map { $_->hash } $messages->all];
    
    return to_json {
    	count => scalar @$message_hashes,
    	messages => $message_hashes ,
    };    	
};


get '/incoming' => sub {
    content_type('application/json');
	my $last_id = param('last_id') || return 'No id specified. Example ?last_id=94500';
    my $messages = schema->resultset('SMS')->search(
    	{
    		id => {'>' => $last_id},
    		direction => 'i',  
    		domain => param('domain'),	
    	},
    	{ 
    		order_by => {'-desc' => 'send_timestamp'}
    	}
    );
    
    return to_json {
    	messages =>  [map { $_->hash_lite } $messages->all],
    };    	
};


get '/incoming/last/:n' => sub {
    content_type('application/json');
	my $limit = param('n') || return 'No limit specified';
    my $messages = schema->resultset('SMS')->search(
    	{
    		direction => 'i',  
    		domain => param('domain'),	
    	},
    	{ 
    		order_by => {'-desc' => 'send_timestamp'},
    		rows => $limit,
    	}
    );
    
    return to_json {
    	messages =>  [map { $_->hash_normal } $messages->all],
    };    	
};

1;
