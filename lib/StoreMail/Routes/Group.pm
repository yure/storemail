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
	
	my $group = StoreMail::Group::find(param('domain'), param('id')) or status 404 and return "Group ".param('id')." not found.";

	my $where;
	
	#$where->{domain} = param('domain');
	$where->{group_id} = $group->id;
	#$where->{direction} = 'o';
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
		my ($group, $new) = StoreMail::Group::new_group(param('domain'), $params);
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


true;
