package Servicator::Routes::Provider;
use Dancer ':syntax';

use Dancer::Plugin::Ajax;
use DBI;
use Servicator::Message;
use Dancer::Plugin::DBIC qw(schema resultset rset);


prefix '/:domain';


get '/provider/:comma_separated_emails' => sub {
	my @emails = map { s/\s*(\S+)\s*/$1/; $_ } split ',', param('comma_separated_emails');
    my $messages = schema->resultset('Message')->search(
    	{
    		-or => [
	    		-and => [
	    			direction => 'i',
	    			-or => [map( (frm => $_), @emails )]
    			],    		
	    		-and => [
	    			direction => 'o',
	    			-or => [map( ('emails.email' => $_), @emails )]
    			],    		
    		]
    	},
    	{ 
			join => 'emails',    		 
    		order_by => 'date',
    	}
    );
    
    return to_json {
    	id => param('email'),
    	subject => param('email'),
    	messages =>  [map { $_->hash } $messages->all],
    };    	
};


true;