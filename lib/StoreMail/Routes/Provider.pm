package StoreMail::Routes::Provider;
use Dancer ':syntax';

use Dancer::Plugin::Ajax;
use DBI;
use StoreMail::Message;
use Dancer::Plugin::DBIC qw(schema resultset rset);


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

	# SQL
	
	my $sql = q|
			SELECT id FROM (

				SELECT m.id, m.date
				FROM email e
				LEFT JOIN message m  ON e.message_id = m.id 
				WHERE  
				domain = ? 
				AND 
				( |. (join ' OR ', map {"e.email = ?"} @emails) .q|  )
				
				UNION
				
				SELECT id, m.date
				FROM message m
				WHERE  
				domain = ? 
				
				AND  
				( |. (join ' OR ', map {"frm = ?"} @emails) .q|  ) 
			
			) a
			
			ORDER BY date 
			
			;|;
	
	my $dbh = schema->storage->dbh;
	my $sth = $dbh->prepare($sql) or die "Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute(param('domain'), @emails, param('domain'), @emails);
	
	my @ids;
	while (my @data = $sth->fetchrow_array()) {
            push @ids, $data[0];
          }
	
	my $where;
	my @join = ('emails');
	
	$where->{-and} = [];
	push $where->{-and}, {id => {'-in' => \@ids}};

	# Search
	my $search =  param('search');
    push $where->{-and},[ -or => [
    	subject => { 'like', "%$search%" },
    	body => { 'like', "%$search%" },
    ]] if $search;

	# Tag Search
	my $tags =  param('tags');
	push @join, 'tags';
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

    my $messages = schema->resultset('Message')->search(
    	$where,
    	{ 
			prefetch => [@join],    		 
		   	#group_by => [ map {"me.$_"} @columns ]	,			 
    	}
    );
    
    return to_json {
    	messages =>  [map { $_->hash } $messages->all],
    };    	
};



true;
