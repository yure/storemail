package StoreMail::Group;
use Dancer ':syntax';

our $VERSION = '0.1';

use StoreMail::Helper;
use Encode;
use Try::Tiny;
require LWP::Simple;

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
	my ($from_name, $from_email) = extract_email($params->{from});
	my $group_name = $params->{group}->{name};
 	my $group_id = $params->{group}->{id};
	
	$params->{group}->{send_only} ||= email_str($group_name, $from_email);
	$params->{group}->{b} ||= $params->{to};
 	warn "no group ID!" and return undef unless $group_id;
	my $mail_domain = domain_setting($domain, 'group_domain');
	unless($mail_domain){
		$mail_domain = config->{'group_domain'};
		$group_id .= "_$domain";
	}
	
	my ($group, $new) = new_group($domain, $params->{group});

	# TO mailing list email
	$params->{from} = email_str($from_name, domain_email($domain));
	$params->{reply_to} = email_str($group->name, $group->email);

	$params->{direction} = 'o'; 

    # Don't send this message
    delete $params->{send_queue};

	# Assign message to group	
	$params->{group_id} = $group->id;

	return $params;
}


sub group_reply_from_message {
	my ($domain, $params) = @_;

	return undef unless $params->{group};

	# Create group
	my ($from_name, $from_email) = extract_email($params->{from});
	$from_name ||= $from_email; # In case there is no name
	my $group_name = $params->{group}->{name};
 	my $group_id = $params->{group}->{id};
 	
 	warn "no group ID!" and return undef unless $group_id;
	
	my ($group, $new) = new_group($domain, $params->{group});
	
	$params->{from} = email_str($from_name, domain_email($domain));
	$params->{reply_to} = email_str($group->name, $group->email);
	
	# Conversation info;
	my $servicator_backend_api = domain_setting($domain, 'servicator_backend_api');
	my ($req_ident_hash, $uid) = split '-', $group_id;
	my $req_ident = substr $req_ident_hash, 5;
	my $req_info = from_json LWP::Simple::get("$servicator_backend_api/request/$uid/$req_ident") or warn 'Unalbe to connect to servicator backend' and return undef;
	
	
	my $to = email_str($req_info->{name}, $req_info->{email});
	assign_to_group($group, $to, 'a');

	# TO mailing list email
	$params->{to} = $to;	
	
	$params->{direction} = 'o';

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
	
	my $group_email = group_email($domain, $id) or printt 'Group email could not be generated' and return (undef, undef);
	my $group_name = $params->{name} || $params->{id};
	
	# Already exists with different data
	my $group = schema->resultset('Group')->find({email => $group_email});
	if($group){
		
		# Has emails
		return ($group, -2) if $group->messages->count;
		
		if(different_group($group, $domain, $params)){
		    return ($group, -1); 
		}
		else {
		    return ($group, 0); 
		}
	}
	
    
	# Save new message to DB
    $group = schema->resultset('Group')->create({
    	email => $group_email,    	
    	name => $group_name,
    	domain => $domain,
    	tag => $params->{tag},
    	domains_id => $params->{id},
    }) or return undef;

	$group->assign_members($params->{'a'}, 'a');
	$group->assign_members($params->{'b'}, 'b');
	$group->assign_members($params->{'send_only'}, 'a', 1, 0);
    	
	return ($group, 1);
}


sub different_group {
	my ($group, $domain, $params) = @_;
	
	# Domain
	return 1 unless $domain eq $group->domain;
	
	# Sides
	for my $side ('a', 'b'){
		for my $p (extract_emails($params->{$side})){
			my $member = {
				side => $side,
				email => $p->{email},
				name => $p->{name}, 
			};
			my $found = $group->find_related('emails', $member);
			return 1 unless $found;
		}
	}
}


sub assign_to_group {
	my ($group, $list, $side, $can_send, $can_recieve) = @_;
	for my $p (@$list){
		my ($name, $email) = extract_email($p);
		my $member = {
			side => $side,
			email => $email,
			name => $name, 
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


sub reply_above_line {
	my ($body, $domain, $type) = @_;
	my $line =  domain_setting($domain, 'write_replay_above');
	return "$line\n\n<br /><br />$body" if $type eq 'html';
	return "$line\n\n$body";	
}

sub remove_reply_above_line {
	my ($body, $domain, $type) = @_;
	return undef unless $body;
	my $line =  domain_setting($domain, 'write_replay_above');
	my $mail_domain = domain_setting($domain, 'group_domain');

	# Storemail reply cut
	my $index = index $body, $line;
	if($index == -1){ # Search for brakelined
		my $flat_line = $line;
		$flat_line =~ s/[\s\r\n=]//g;
		my @matches = $body =~ /(=[$line\n\r]{41}=)/s;
		for my $match (@matches){
			my $match_check = $match;
			$match_check =~ s/[\s\r\n=]//g;
			$index = index $body, $match if $flat_line eq $match_check;
		}
	}
	$body = substr $body, 0, $index if $index > -1;
	
	# Gmail reply
	$body =~ /(On .*? at .*?$mail_domain.*?wrote:)/s;
	my ($gmail_timestamp) = ($1);
	if($gmail_timestamp){
		$index = index $body, $gmail_timestamp;
		$body = substr $body, 0, $index if $index > -1;
		$gmail_timestamp = undef;
	}
	
	# Gmail reply ver 3 - 27. jun. 2016 17:46 je oseba "darija" <darija.marolts@gmail.com> napisala:
	$body =~ /([0-9]*?\. [a-z]*?\. [0-9]*? .*? .*?$mail_domain.*?:)/s;
	($gmail_timestamp) = ($1);
	if($gmail_timestamp){
		$index = index $body, $gmail_timestamp;
		$body = substr $body, 0, $index if $index > -1;
		$gmail_timestamp = undef;
	}
	
	# Gmail reply ver2 - 2016-09-02 13:28 GMT+02:00 cerere [[62c4065147-61949]] conversation@dev.trebam.hr Grega Pompe
	$body =~ /([0-9]*?-[0-9]*?-[0-9]*? [0-9]*?:[0-9]*? .*?$mail_domain.*?:)/s;
	($gmail_timestamp) = ($1);
	if($gmail_timestamp){
		$index = index $body, $gmail_timestamp;
		$body = substr $body, 0, $index if $index > -1;
		$gmail_timestamp = undef;
	}

	return $body;
}


sub send_group {
	my ($message) = @_;
	
	return "Not group msg" unless $message->source;
	
	$message->discard_changes;
		
	for my $recipient ($message->toccbcc){
		my $group = schema->resultset('Group')->find({ email => $recipient->email });
		next unless $group;
		
		my $sender_member = schema->resultset('GroupEmail')->find({ email => $message->frm, group_id => $group->id }) 
			or warn $message->frm . " not authorized to send to group " . $group->email 
			and return "Not authorized to send to group";
		
		my $incoming_message = make_incoming($group, $message, $recipient) 
			or warn "Unable to make incoming from id ".$message->id."!" 
			and return "Unable to make incoming from id";
			
		next if $message->source eq 'import_group';
		
		my $outgoing_message_data = prepare_outgoing($group, $incoming_message);
		for my $member ($group->emails->search({side => { '!=' => $sender_member->side }, can_recieve => 1})->all){			
			make_outgoing($incoming_message, $outgoing_message_data, $member);
		}
		return "OK";
	}
	
	return "Group not found";
}


sub make_incoming {
	my ($group, $message, $recipient) = @_;
	
	my ($frm_name, $frm_email) = extract_email($message->frm);
	my $sender = $group->emails->find({email => $frm_email});
	
	my $response = StoreMail::Message::new_message(
		direction => 'i',
		body => html_cleanup(remove_reply_above_line($message->body, $group->domain, 'html')),
    	body_type => 'html',
    	raw_body => $message->raw_body,
    	plain_body => remove_reply_above_line($message->plain_body, $group->domain, 'plain'),
    	subject => $message->subject,
    	domain => $group->domain,
		from => $sender->named_email,
		name => $message->name,
		date => $message->date,
		reply_to => $group->name .'<'.$group->email.'>',
		source => undef,
		group_message_parent_id => $message->id,
		group_id => $group->id,
	);
		
	my $incoming_message = $response->{message};

	 # Add recipients
    $incoming_message->update_or_create_related('emails', {
    	email => $recipient->email, 
    	name => $group->name, 
    	type => 'to', 
    });
		
	# Add attachments
    $incoming_message->copy_attachments($message);    	
		
	$incoming_message->update;
	return $incoming_message;
}


sub make_outgoing {
	my ($message, $message_data, $member) = @_;
	
	my $response = StoreMail::Message::new_message(%$message_data);
		
	my $outgoing_message = $response->{message};

	 # Add recipients
    $outgoing_message->update_or_create_related('emails', {
    	email => $member->email, 
    	name => $member->name, 
    	type => 'to', 
    });
		
	# Add attachments
    $outgoing_message->copy_attachments($message);    	
		
	# Send it
	$outgoing_message->send_queue(1);
		
	$outgoing_message->update;
	return $outgoing_message;
}



sub prepare_outgoing {
	my ($group, $message) = @_;
	
	my $from_name = $message->name || $message->frm;
	
	my $body = $message->body;
	my $plain_body = $message->plain_body;
	$body = add_conversation_history($group, $message, 'html');
	$plain_body = add_conversation_history($group, $message, 'plain');
	
	return {
		direction => 'o',
		body => reply_above_line($body, $group->domain, 'html'),
    	body_type => 'html',
    	raw_body => $message->raw_body,
    	plain_body => reply_above_line($plain_body, $group->domain, 'plain'),
    	subject => $message->subject,
    	domain => $group->domain,
		from => email_str($from_name, domain_email($group->domain)),
		reply_to => $group->name .'<'.$group->email.'>',
		source => undef,
		group_message_parent_id => $message->id,
		group_id => $group->id,
	}

}


sub add_conversation_history {
	my ($group, $message, $type) = @_;
	
	my $older_messages = $group->messages->search(
    	{date => {'<=' => $message->date}, direction => 'i'},
    	{order_by => {'-desc' => 'date'}	}
    );
    
    my $body;
    return template 'message_conversation.html', {messages => [$older_messages->all]}, {layout => undef};
    for my $older_msg ($older_messages->all){
    	$body .= attach_history_message($older_msg, $type);
    }
	return $body;
}


sub attach_history_message {
	my ($message, $type) = @_;
	return "\n----- ".$message->date." - ".$message->named_or_email." -----\n".$message->plain_body if $type eq 'plain';
	
	return "<br><br>----- ".$message->date." - ".$message->named_or_email." -----<br>".$message->body;
}


sub group_email {
	my ($domain, $id) = @_;
	my $short_name = domain_setting($domain, 'short_name') or return undef;
	my $mail_domain = domain_setting($domain, 'group_domain') or return undef;
	return $id .'-'. $short_name .'@'. $mail_domain;
}


sub find {
	my ($domain, $id) = @_;
	return schema->resultset('Group')->find({domain => $domain, domains_id => $id});
	
}




true;
