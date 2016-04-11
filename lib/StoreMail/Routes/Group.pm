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




get '/email_list/:email' => sub {
	content_type('application/json');
	
	my $group = schema->resultset('Group')->find({email => param('email')}) or status 404 and return "Group ".param('id')." not found.";

	my $where;
	
	#$where->{domain} = param('domain');
	$where->{group_id} = $group->id;
	my $messages = schema->resultset('Message')->search(
    	$where,
    	{ 
    		order_by => 'date',	   		
    	}
    );
    
	my @messages = $messages->all;
	return to_json {
		name => $group->name,
		message_count => scalar @messages,
    	messages =>  [map { $_->hash } @messages],
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
    try{
		# Create
		$group = StoreMail::Group::new_group(param('domain'), $params);
    }
    catch {	
    	warn "FAILED TO CREATE GROUP: " . to_json $params;
    	$error_message = $_;
    };

	if ($error_message or !$group){
		status 400;    
	}
    
    return $error_message->{msg} if $error_message;
    return 'Error' unless $group;
    
    # Message created
    status 201;
    return to_json $group->hash;
};


true;
