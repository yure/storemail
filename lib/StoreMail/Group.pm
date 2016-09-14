package StoreMail::Group;
use Dancer ':syntax';

our $VERSION = '0.1';

use Dancer::Plugin::DBIC qw(schema resultset rset);
use StoreMail::Helper;;
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
    	domains_id => $params->{id},
    });

	assign_to_group($group, $params->{'a'}, 'a');
	assign_to_group($group, $params->{'b'}, 'b');
	assign_to_group($group, $params->{'send_only'}, 'a', 1, 0);
    	
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


sub reply_above_line {
	my ($body, $mail_domain, $type) = @_;
	return undef unless $body;
	my $line = config->{"write_replay_above"};

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

	# HTML cleanup
	if($type eq 'html'){
		my $filename = rand(100000000000).'.html';
		open(my $fh, '>', $filename);
		print $fh "$line\n\n<br /><br />";
		print $fh $body;
		close $fh;
		my $cleaned_body = `tidy --word-2000 true --input-encoding utf8 --force-output true -f err.txt  $filename`; #--output-encoding utf8
		unlink $filename;
		if( $cleaned_body){
			$body = $cleaned_body ;
		}
		else{
			$body = "$line\n\n<br /><br />$body";		
		}
	} else {
		$body = "$line\n\n$body";
	}

	return remove_utf8_4b $body;
}


sub send_group {
	my ($message) = @_;
	
	return undef unless $message->source;
	$message->discard_changes;
		
	for my $c ($message->toccbcc){
		my $group = schema->resultset('Group')->find({ email => $c->email });
		next unless $group;
		
		my $sender_member = schema->resultset('GroupEmail')->find({ email => $message->frm, group_id => $group->id });
		
		unless( $sender_member){
			warn $message->frm . " not authorized to send to group " . $group->email;
			return 0;
		}
		
		for my $c ($group->emails->search({side => { '!=' => $sender_member->side }, can_recieve => 1})->all){
			
			my $from_name = $message->name || $message->frm;
			my $mail_domain = domain_setting($group->domain, 'group_domain');
			
			my $response = StoreMail::Message::new_message(
						direction => 'o',
						
						body => reply_above_line($message->body, $mail_domain, $message->body_type),
				    	body_type => $message->body_type,
				    	raw_body => $message->raw_body,
				    	plain_body => reply_above_line($message->plain_body, $mail_domain, 'plain'),
				    	subject => $message->subject,
				    	domain => $group->domain,
						from => email_str($from_name, domain_email($group->domain)),
						reply_to => $group->name .'<'.$group->email.'>',
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
		return 1;
	}
	
	return 0;
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
