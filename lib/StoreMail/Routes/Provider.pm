package StoreMail::Routes::Provider;
use Dancer ':syntax';

use Dancer::Plugin::Ajax;
use DBI;
use StoreMail::Message;
use Dancer::Plugin::DBIC qw(schema resultset rset);


prefix '/:domain';


get '/provider/unread/:comma_separated_emails' => sub {
	content_type('application/json');
	
	return to_json {error => 'No emails specified'} if (index (param('comma_separated_emails'), '@') < 0); 
	
	my @emails = map { s/\s*(\S+)\s*/$1/; $_ } split ',', param('comma_separated_emails');
    my $messages = schema->resultset('Message')->search(
    	{
    		'new' => 1,
    		domain => param('domain'),
    		-or => [
	    		-and => [
	    			-or => [map( (frm => $_), @emails )]
    			],    		
	    		-and => [
	    			-or => [map( ('emails.email' => $_), @emails )]
    			],    		
    		],
    	},
    	{ 
			join => 'emails',
#			group_by => [ qw/id/ ],
    		order_by => 'date',
    	}
    );
    
    return to_json {
    	messages =>  [map { $_->hash } $messages->all],
    };    	
};


get '/provider/:comma_separated_emails' => sub {
	content_type('application/json');
	
	return to_json {error => 'No emails specified'} if (index (param('comma_separated_emails'), '@') < 0);
	
	my @emails = map { s/\s*(\S+)\s*/$1/; $_ } split ',', param('comma_separated_emails');
	
	# Remove duplicates / yes, this happens
	my %hash   = map { $_, 1 } @emails;
   	@emails = keys %hash;

	#debug('emails :', \@emails);

	my $where;
	$where->{-and} = [];
	push $where->{-and}, [ -or => [
	    		-and => [
	    			-or => [map( (frm => $_), @emails )]
    			],    		
	    		-and => [
	    			-or => [map( ('emails.email' => $_), @emails )]
    			],    		
    		]];

	# Search
	my $search =  param('search');
    push $where->{-and},[ -or => [
    	subject => { 'like', "%$search%" },
    	body => { 'like', "%$search%" },
    ]] if $search;

	# Tag Search
	my $tags =  param('tags');
	if($tags){
		my @tags_condition;
		for my $tag (split ',', $tags){
			#push $where->{-and}, {'tags.value' => $tag};
		    push @tags_condition, 'tags.value' => $tag;
		}
	     push $where->{-and},[ -or => [
	    	@tags_condition
	    ]] if @tags_condition;
	}
    	
	# Date span
	my $from =  param('from');
	my $to =  param('to');
	#my $parser   = schema->storage->datetime_parser;
    push $where->{-and}, {date => { '<=', $to }} if $to;
    push $where->{-and}, {date => { '>=', $from }} if $from;

    my $rs = schema->resultset('Message')->result_source;
    my @columns = $rs->columns;	

    $where->{domain} = param('domain');
    my $messages = schema->resultset('Message')->search(
    	$where,
    	{ 
			join => ['emails', 'tags'],    		 
    		order_by => 'date',
	   	group_by => [ map {"me.$_"} @columns ]		
    	}
    );
    
    return to_json {
    	messages =>  [map { $_->hash } $messages->all],
    };    	
};



true;
