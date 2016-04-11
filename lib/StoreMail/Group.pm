package StoreMail::Group;
use Dancer ':syntax';

our $VERSION = '0.1';

use Dancer::Plugin::DBIC qw(schema resultset rset);
use StoreMail::Helper;;
use Encode;
use Try::Tiny;

sub group_email_list {
	my $list = shift;
	return undef unless $list;
	return [$list] if ! ref $list;
	return $list if ref $list eq 'ARRAY';
}


sub new_group_from_message {
	my ($domain, $params) = @_;

	return undef unless $params->{group};

	# Create group
	$params->{group}->{a} ||= $params->{from};
	$params->{group}->{b} ||= $params->{to};
 	my $id = $params->{group}->{id};
 	warn "no group ID!" and return undef unless $id;
	my $mail_domain = domain_setting($domain, 'catchall_domain');
	unless($mail_domain){
		$mail_domain = config->{'catchall_domain'};
		$id .= "_$domain";
	}
	
	my $group = new_group($domain, $params->{group});

	# TO mailing list email
	my ($name, $email) = extract_email($params->{from});
	$params->{to} = email_str($group->name, $group->email);	

    # Don't send this message
    delete $params->{send_queue};

	# Assign message to group	
	$params->{group_id} = $group->id;

	return $params;
}

sub new_group {
	my ($domain, $params) = @_;

	return undef unless $params;

	# Create group
 	my $id = $params->{id};
 	warn "no group ID!" and return undef unless $id;
	my $mail_domain = domain_setting($domain, 'catchall_domain');
	unless($mail_domain){
		$mail_domain = config->{'catchall_domain'};
		$id .= "_$domain";
	}
	
	my $group_email = "$id\@$mail_domain";
	
	# Save new message to DB
    my $group = schema->resultset('Group')->find_or_create({
    	email => $group_email,    	
    	name => $params->{name} || $params->{id},
    });

	assign_to_group($group, $params->{'a'}, 'a');
	assign_to_group($group, $params->{'b'}, 'b');
	assign_to_group($group, $params->{'send_only'}, 'a', 1, 0);
    	
	return $group;
}


sub assign_to_group {
	my ($group, $list, $side, $can_send, $can_recieve) = @_;
	for my $p (extract_emails($list)){
		my $member = {
			side => $side,
			email => $p->{email},
			name => $p->{name}, 
		};
		$member->{can_recieve} = $can_recieve if defined $can_recieve;
		$member->{can_send} = $can_send if defined $can_send;
		try{				
	    	$group->update_or_create_related('emails', $member);
		}
		catch{
			warn $p->{email}." not assigned to $side";
		};
    }
}


sub send_group {
	my ($message) = @_;
	
		
	for my $c ($message->toccbcc){
		my $group = schema->resultset('Group')->find({ email => $c->email });
		next unless $group;
		
		my $sender_member = schema->resultset('GroupEmail')->find({ email => $message->frm, group_id => $group->id });
		
		unless( $sender_member){
			warn $message->frm . " not authorized to send to group " . $group->email;
			return -1;
		}
		
		for my $c ($group->emails->search({side => { '!=' => $sender_member->side }, can_recieve => 1})->all){
			
			my $from_name = $group->name . " (".config->{domain}.")";
			my $response = StoreMail::Message::new_message(							
						direction => 'o',										
						
						body => $message->body,
				    	body_type => $message->body_type,
				    	raw_body => $message->raw_body,
				    	plain_body => $message->plain_body,
				    	subject => $message->subject,
				    	domain => $message->domain,
						#from => $message->frm,
						
						from => $group->email,
						reply_to => $from_name .'<'.$group->email.'>',
						source => undef,
						group_message_parent_id => $message->id,
						group_id => $group->id,									
					);
			
			my $fwd_message = $response->{message};
			$fwd_message->name($message->name);
	
			 # Add recipients
	    	$fwd_message->update_or_create_related('emails', {
	    		email => $c->email, 
	    		name => $c->name, 
	    		type => 'to', 
	    	});
			
			    
		    # TODO Add attachments
	    	$fwd_message->copy_attachments($message);    	
			
			
			# Send it
			$fwd_message->send_queue(1);
			
			$fwd_message->update;
		}
	}
	
	return 1;
}

true;
