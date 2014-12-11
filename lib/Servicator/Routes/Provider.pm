package Servicator::Routes::Provider;
use Dancer ':syntax';

use Dancer::Plugin::Ajax;
use DBI;
use Servicator::Message;
use Dancer::Plugin::DBIC qw(schema resultset rset);


prefix '/:domain';


get '/provider/unread/:comma_separated_emails' => sub {
	my @emails = map { s/\s*(\S+)\s*/$1/; $_ } split ',', param('comma_separated_emails');
    my $messages = schema->resultset('Message')->search(
    	{
    		'new' => 1,
    		domain => param('domain'),
    		-or => [
	    		-and => [
	    			direction => 'i',
	    			-or => [map( (frm => $_), @emails )]
    			],    		
	    		-and => [
	    			direction => 'o',
	    			-or => [map( ('emails.email' => $_), @emails )]
    			],    		
    		],
    	},
    	{ 
			join => 'emails',    		 
    		order_by => 'date',
    	}
    );
    
    return to_json {
    	messages =>  [map { $_->hash } $messages->all],
    };    	
};


get '/provider/:comma_separated_emails' => sub {
	my @emails = map { s/\s*(\S+)\s*/$1/; $_ } split ',', param('comma_separated_emails');
	my $where;
	$where->{-and} = [];
	push $where->{-and}, [ -or => [
	    		-and => [
	    			direction => 'i',
	    			-or => [map( (frm => $_), @emails )]
    			],    		
	    		-and => [
	    			direction => 'o',
	    			-or => [map( ('emails.email' => $_), @emails )]
    			],    		
    		]];

	# Search
	my $search =  param('search');
    push $where->{-and},[ -or => [
    	subject => { 'like', "%$search%" },
    	body => { 'like', "%$search%" },
    ]] if $search;
    	
	# Date span
	my $from =  param('from');
	my $to =  param('to');
	#my $parser   = schema->storage->datetime_parser;
    push $where->{-and}, {date => { '<=', $to }} if $to;
    push $where->{-and}, {date => { '>=', $from }} if $from;

    	
    $where->{domain} = param('domain');
    my $messages = schema->resultset('Message')->search(
    	$where,
    	{ 
			join => 'emails',    		 
    		order_by => 'date',
    	}
    );
    
    return to_json {
    	messages =>  [map { $_->hash } $messages->all],
    };    	
};



true;