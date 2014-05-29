=encoding utf8

=pod
 
=head1 NAME
 
Servicator
 
=head1 SYNOPSIS
 
Mailing service with threaded conversation backend. 
 
=head1 CONFIGURATION

=head2 Config files
 
Setup mailing provider and DB info in config.yml. Example below:

	catch_all:
	  host: 'imap.gmail.com'
	  port: 993
	  username: 'info@mail.com'
	  password: 'passss'
	  ssl: 1


	plugins:
	  DBIC:
	    default:
	      dsn: dbi:mysql:dbname=Servicator
	      schema_class: Servicator::Schema
	      user: root
	      pass: toor
	      options:
	        mysql_enable_utf8: 1
     Email:
	    transport:
	      SMTP:
	        host: 'smtp.mandrillapp.com'
	        port: 587
	        sasl_username: 'info@mail.com'
	        sasl_password: 'passss'
	  
=head2 Runing services

You need to run dancer application (bin/app.pl), to handle API requests and bin/catchall.pl script to fetch mail from inbox.


=head1 API Use

All API routes start with your domain. 

=head2 Conversation

=head3 Conversation data

GET /:domain/conversation/:id
	
Returns:

	{messages: [ 
		{
			body: string,
			conversation_id: string,  
			date: string,  
			id: string,  
			sender: string,  
		}	
	]	
	
=cut	
