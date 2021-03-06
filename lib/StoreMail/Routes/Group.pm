package StoreMail::Routes::Group;
use Dancer ':syntax';

use Dancer::Plugin::Ajax;
use DBI;
use StoreMail::Message;
use StoreMail::Group;
use StoreMail::Helper;
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
	my $group = schema->resultset('Group')->find({domain => param('domain'), domains_id => param('id')}) or status 404 and return "Group ".param('id')." not found.";
	my $where;
	
	$where->{group_id} = $group->id;
	$where->{direction} = 'i';
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
    	$error_message = "FAILED TO CREATE GROUP: " . to_json($params) . "\n ERROR: " . to_dumper($_);
    	warn $error_message;
    };

	status 400 and return $error_message if $error_message;
    status 400 and return 'Error. Group not created' unless $group;

	# Already exists    
	if($new == -1){
		my $msg = "Already exists, but different! \n";
    	status 409;
    	warn $msg;
    	return $msg;
	}
	if($new == -2){
		my $msg = "Already exists with sent emails! \n";
    	status 409;
    	warn $msg;
    	return $msg;
	}

    # Message created
    status 201 and return to_json $group->hash;
};


post '/add-members' => sub {
    content_type('application/json');
    
	my $rawparams = param('data');
	my $params;
	try{
		$params = from_json encode('utf8', $rawparams);	
	};
	status 400 and return "Malformed JSON" unless $params;
	status 406 and return "A or B can't be empty" unless $params->{'a'} or $params->{'b'};	
	status 406 and return "I can't be empty" unless $params->{'id'};	
	
    my $error_message;
    my $group = StoreMail::Group::find(param('domain'), $params->{id}) or status 404 and return "Group not found";
	

	my $errors;
	$errors .= $group->assign_members($params->{'a'}, 'a') if $params->{'a'};
	$errors .= $group->assign_members($params->{'b'}, 'b') if $params->{'b'};
	$errors .= $group->assign_members($params->{'send_only'}, 'a', 1, 0) if $params->{'send_only'};

    # Message created
    my $return = $group->hash;
    $return->{errors} = $errors;
    status 201 and return to_json $return;
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
	
	# Find group by id
	if($params->{group_id}){
		my $group = StoreMail::Group::find(param('domain'), $params->{group_id});
		status 406 and return "Group with id ".$params->{group_id}." not found" unless $group;
		$params->{to} = $group->email;
		delete $params->{group_id};
	}
	
	status 406 and return "FROM can't be empty" unless $params->{'from'};
	status 406 and return "TO can't be empty" unless $params->{'to'};
	status 406 and return "SUBJECT can't be empty" unless $params->{'subject'};
	
    my $message;
    my $error_message;
    my $group_send;
    try{
		# Create
	    my $response = StoreMail::Message::new_message(
					direction => 'i',
					domain => param('domain'),
					track => param('track'),
					source => 'group_direct',
					internal => 1,
					%$params
				);
		$message = $response->{message};
		$group_send = $response->{group_send};
    }
    catch {	
    	warn "FAILED TO SEND: " . to_json $params;
    	$error_message = $_;
    };


	if ($group_send and $group_send ne 'OK'){
		status 400;
	    return $group_send;
	}


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
