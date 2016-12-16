package StoreMail::Routes::Provider;
use Dancer ':syntax';

use Dancer::Plugin::Ajax;
use DBI;
use StoreMail::Message;
use StoreMail::Helper;


prefix '/:domain/provider';


get '/unread/:comma_separated_emails' => sub {
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


get '/:comma_separated_emails' => sub {
	content_type('application/json');
	
	return to_json {error => 'No emails specified'} if (index (param('comma_separated_emails'), '@') < 0);
	
	my @emails = map { s/\s*(\S+)\s*/$1/; $_ } split ',', param('comma_separated_emails');
	
	# Remove duplicates / yes, this happens
	my %hash   = map { $_, 1 } @emails;
   	@emails = keys %hash;

	my $limit = 100; # Timeout in case of large set

	# SQL
	
	my $sql = q|
			SELECT id FROM (

				SELECT m.id, m.date
				FROM email e
				LEFT JOIN message m  ON e.message_id = m.id 
				WHERE  
				group_id IS NULL
				AND
				internal = 0				
				AND
				domain = ? 
				AND 
				( |. (join ' OR ', map {"e.email = ?"} @emails) .q|  )
				
				UNION
				
				SELECT m.id, m.date
				FROM message m
				WHERE
				group_id IS NULL  
				AND
				internal = 0
				AND
				domain = ? 
				
				AND  
				( |. (join ' OR ', map {"frm = ?"} @emails) .q|  )
			
			) a
			
			LEFT JOIN tag t_pass  ON t_pass.message_id = a.id AND t_pass.value = 'new-password'
			WHERE
			t_pass.value IS NULL				
			
			ORDER BY id DESC 
			LIMIT |.$limit.q|
			
			;|;
	
	my $dbh = schema->storage->dbh;
	my $sth = $dbh->prepare($sql) or die "Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute(param('domain'), @emails, param('domain'), @emails);
	
	my @ids;
	while (my @data = $sth->fetchrow_array()) {
            push @ids, $data[0];
          }
	
	my $where = {'me.id' => {'-in' => \@ids}};
	my @join = ('emails', 'tags');
	

    my $rs = schema->resultset('Message')->result_source;
    my @columns = $rs->columns;	

    my $messages = schema->resultset('Message')->search(
    	$where,
    	{ 
			prefetch => [@join],    		 
		   	rows => $limit,
		   	order_by => {'-desc' => 'date'},		 
    	}
    );
    
    return to_json {
    	messages =>  [map { $_->hash } $messages->all],
    };    	
};



true;
