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

	$group->assign_members($params->{'send_only'}, 'a', 1, 0);
	$group->assign_members($params->{'send_only_a'}, 'a', 1, 0);
	$group->assign_members($params->{'send_only_b'}, 'b', 1, 0);
	$group->assign_members($params->{'a'}, 'a', 1, 1);
	$group->assign_members($params->{'b'}, 'b', 1, 1);
    	
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
		
		# Get side from email replied to
		my ($group_email, $side) = extract_side($recipient->email);
		my $group = schema->resultset('Group')->find({ email => $group_email });
		next unless $group;

		# Find side from group member
		unless($side){
			my $sender_member = schema->resultset('GroupEmail')->find({ email => $message->frm, group_id => $group->id }) 
				or warn $message->frm . " not authorized to send to group " . $group->email 
				and send_info($group, $message)
				and return "Not authorized to send to group";
				$side ||= $sender_member->side;
		}
		next unless $side;
		
		my $incoming_message = make_incoming($group, $message, $recipient, $side) 
			or warn "Unable to make incoming from id ".$message->id."!" 
			and return "Unable to make incoming from id";
			
		next if $message->source eq 'import_group';
		
		my $outgoing_message_data = prepare_outgoing($group, $incoming_message, $side);
		for my $member ($group->emails->search({side => { '!=' => $side }, can_recieve => 1})->all){			
			make_outgoing($group, $incoming_message, $outgoing_message_data, $member);
		}
		return "OK";
	}
	
	return "Group not found";
}


sub add_side {
	my ($email, $side) = @_;
	$email =~ s/@/_$side@/g;
	return $email;
}


sub extract_side {
	my ($email) = @_;
	my ($side) = $email =~ /-.*_(.*)@/;
	$email =~ s/_$side@/@/g;
	return ($email, $side);
}


sub make_incoming {
	my ($group, $message, $recipient, $side) = @_;
	
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
		from => $sender ? $sender->named_email : $message->frm,
		name => $message->name,
		date => $message->date,
		#reply_to => email_str($group->name, add_side($group->email, $side)),
		source => undef,
		group_message_parent_id => $message->id,
		group_id => $group->id,
		internal => 0,
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
	my ($group, $message, $message_data, $member) = @_;
	
	# Set reply to with side indicator
	$message_data->{reply_to} = email_str($group->name, add_side($group->email, $member->side));
	
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


sub send_info {
	my ($group, $message) = @_;
		
	my $outgoing_message = $message->make_copy;
	$outgoing_message->subject('REJECTED REPLY (sent from unauthorized email) - '.$outgoing_message->subject); 
	$outgoing_message->domain($group->domain); 
	

	 # Send to info	
	my ($info_name, $info_email) = extract_email(domain_setting($group->domain, 'info_email'));
    $outgoing_message->update_or_create_related('emails', {email => $info_email, name => $info_name, type => 'to',}) if $info_email;
	my ($admin_name, $admin_email) = extract_email(config->{admin_email});
    $outgoing_message->update_or_create_related('emails', {email => $admin_email, name => $admin_name, type => 'to',}) if $admin_email;
		
	# Send it
	$outgoing_message->send_queue(1);
		
	$outgoing_message->update;

	# Add attachments
    $outgoing_message->copy_attachments($message);    	
	return $outgoing_message;
}



sub prepare_outgoing {
	my ($group, $message, $side) = @_;
	
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
