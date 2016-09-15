#!/usr/bin/env perl
use Dancer ':script';
use open ':std', ':encoding(UTF-8)';
use StoreMail::SMS;
use Try::Tiny;
use StoreMail::Helper;
use DateTime::Format::MySQL;
use Dancer::Plugin::Email;
use Getopt::Long;
use DBI;

my $limit = 10;
my $email ;
my $domain = 'www.primerjam.si';

GetOptions(    
    "limit=i" => \$limit,
    "email=s" => \$email,
    "domain=s" => \$domain,
    #"gateway=s" => \$gateway_id,
    ) or die $!;
    
    
my @emails = ($email);
my $where;
my @join = ('emails');

if($email){
	
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
		$sth->execute($domain, @emails, $domain, @emails);
		
		my @ids;
		while (my @data = $sth->fetchrow_array()) {
	            push @ids, $data[0];
	          }
		
		
		$where->{-and} = [];
		push $where->{-and}, {id => {'-in' => \@ids}};
}

    
 my $messages = schema->resultset('Message')->search(
    	$where,
    	{ 
			prefetch => [@join],    		 
		   	#group_by => [ map {"me.$_"} @columns ]	,	
		   	rows => $limit,		 
		   	order_by => {'-desc' => 'date'},
    	}
    );    
    
 
for my $message ($messages->all){
	print "\n".$message->id. 
	' ['.$message->date. '] '
	.$message->frm . ' -> ' 
	.join (', ', map {$_->email} $message->to) ." | "  
	.$message->subject
	.($message->send_queue ? ' QUEUED ' : '')
	.($message->opened ? ' OPENED ' : '')
	.($message->batch_id ? ' BATCH '.$message->batch_id." " : '')
	.($message->group_id ? ' GROUP '.$message->group_id." " : '')
	
	;
}
print "\n";    
#printt "Limit is $limit. Searching for $email";