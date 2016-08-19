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
	
	# Already exists
	my $group = schema->resultset('Group')->find({email => $group_email});
    return ($group, 0) if $group;
    
	# Save new message to DB
    $group = schema->resultset('Group')->create({
    	email => $group_email,    	
    	name => $params->{name} || $params->{id},
    	domain => $domain,
    	domains_id => $params->{id},
    });

	assign_to_group($group, $params->{'a'}, 'a');
	assign_to_group($group, $params->{'b'}, 'b');
	assign_to_group($group, $params->{'send_only'}, 'a', 1, 0);
    	
	return ($group, 1);
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
	my ($body, $mail_domain) = @_;
	return undef unless $body;
	
	# Storemail reply
	my $line = "===== WRITE YOUR REPLY ABOVE THIS LINE =====";
	my $index = index $body, $line;
	$body = substr $body, 0, $index if $index > -1;
	
	# Gmail reply
	$body =~ /(On .*? at .*?$mail_domain.*?wrote:)/s;
	my ($gmail_timestamp) = ($1);
	if($gmail_timestamp){
		$index = index $body, $gmail_timestamp;
		$body = substr $body, 0, $index if $index > -1;
	}
	
	return "$line\n\n\n$body";
}


sub send_group {
	my ($message) = @_;
	
	return undef unless $message->source;
		
	for my $c ($message->toccbcc){
		my $group = schema->resultset('Group')->find({ email => $c->email });
		next unless $group;
		
		my $sender_member = schema->resultset('GroupEmail')->find({ email => $message->frm, group_id => $group->id });
		
		unless( $sender_member){
			warn $message->frm . " not authorized to send to group " . $group->email;
			return 0;
		}
		
		for my $c ($group->emails->search({side => { '!=' => $sender_member->side }, can_recieve => 1})->all){
			
			my $from_name = $group->name . " (".config->{domain}.")";
			my $mail_domain = domain_setting($message->domain, 'group_domain');
			
			my $response = StoreMail::Message::new_message(							
						direction => 'o',
						
						body => reply_above_line($message->body, $mail_domain),
				    	body_type => $message->body_type,
				    	raw_body => reply_above_line($message->raw_body, $mail_domain),
				    	plain_body => reply_above_line($message->plain_body, $mail_domain),
				    	subject => $message->subject,
				    	domain => $message->domain,
						from => $from_name . domain_email($message->domain),
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
	my $email = group_email($domain, $id);
	return schema->resultset('Group')->find({email => $email});
	
}


sub domain_email {
	my ($domain) = @_;
	my $mail_domain = domain_setting($domain, 'group_domain');
	return "conversation\@$mail_domain";
}

true;
