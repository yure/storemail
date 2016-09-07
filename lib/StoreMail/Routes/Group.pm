package StoreMail::Routes::Group;
use Dancer ':syntax';

use Dancer::Plugin::Ajax;
use DBI;
use StoreMail::Message;
use StoreMail::Group;
use Dancer::Plugin::DBIC qw(schema resultset rset);
use Encode;
use Try::Tiny;

prefix '/:domain/group';




get '/info/:id' => sub {
	content_type('application/json');
	my $group = StoreMail::Group::find(param('domain'), param('id')) or status 404 and return "Group ".param('id')." not found.";
	return to_json $group->hash;
};


get '/email_list/:id' => sub {
	content_type('application/json');
	my $group = schema->resultset('Group')->find({domain => param('domain'), domains_id => param('id')});
	my $where;
	
	$where->{group_id} = $group->id;
	my $messages = schema->resultset('Message')->search(
    	$where,
    	{ 
			order_by => 'date',
    	}
    );
    
	my @messages = $messages->all;
	
	my @group_messages;
	my $line = config->{"write_replay_above"};
	for my $message (@messages){
		my $hash = $message->hash();
		$hash->{body} =~ s/$line//g;
		push @group_messages, $hash
	}
	
	return to_json {
		name => $group->name,
		message_count => scalar @messages,
    	messages =>  \@group_messages,
    }; 
};


post '/create' => sub {
    content_type('application/json');
    
	my $rawparams = param('data');
	my $params;
	try{
		$params = from_json encode('utf8', $rawparams);	
	};
	status 400 and return "Malformed JSON" unless $params;
	status 406 and return "A and B can't be empty" unless $params->{'a'} and $params->{'b'};	
	
    my $error_message;
    my $group;
    my $new; 
    try{
		# Create
		($group, $new) = StoreMail::Group::new_group(param('domain'), $params);
    }
    catch {	
    	warn "FAILED TO CREATE GROUP: " . to_json $params;
    	$error_message = $_;
    };

	status 400 and return $error_message if $error_message;        
    status 400 and return 'Error. Group not greated' unless $group;

	# Already exists    
    status 409 and return to_json $group->hash unless $new;

    # Message created
    status 201 and return to_json $group->hash;
};


get '/:email' => sub {
    content_type('application/json');
    
    my $group = schema->resultset('Group')->find({email => param('email')}) or status 404 and return "Group ".param('id')." not found.";
    return to_json $group->hash;
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
					direction => 'i',
					domain => param('domain'),
					track => param('track'),
					source => 'group_direct',
					%$params
				);
		$message = $response->{message};
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

true;
