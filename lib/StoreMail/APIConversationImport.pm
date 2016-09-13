package StoreMail::APIConversationImport;
use Dancer ':syntax';

# Importing old conversations from CRM system. Only for transitional period.

use Dancer::Plugin::DBIC qw(schema resultset rset);
use StoreMail::Message;
use StoreMail::Helper;
use StoreMail::Group;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use Try::Tiny; 
require LWP::Simple;


my $appdir = config->{appdir};
my $last_id_file = "$appdir/conversation_import_last_modified.txt";
my $source_name = 'import_group';

sub set_last_modified {
	my $time = shift;
	open(my $fh, '>', $last_id_file) or die "Could not open file '$last_id_file' $!";
	print $fh $time;
	close $fh;
	print "done\n"
}


sub get_last_modified {
	open(my $fh, '<:encoding(UTF-8)', $last_id_file) or die "Could not open file '$last_id_file' $!";
	my $row = <$fh>;
	close $fh;
	return $row;
}


sub import_all {
	my $args = {@_};		
	my $gmail = config->{gmail};
	my $start_time = time;
	my $last_modified = $args->{last_modified} || get_last_modified;
    for my $domain ('www.necesit.ro'){ #keys %{config->{domains}} 'www.trebam.hr'

		my $servicator_backend_api = domain_setting($domain, 'servicator_backend_api') or next;
		printt $domain;
		my $conversation_list_url = "$servicator_backend_api/conversation?last_modified=$last_modified";
		
		my $content = LWP::Simple::get($conversation_list_url) or print "Couldn't get $conversation_list_url" and next;
		my $conversations = from_json $content;
		
		for my $conversation_id (@$conversations){
			my $conversation_data_url = "$servicator_backend_api/conversation?id=$conversation_id";
			
			my $conversation_data_content = LWP::Simple::get($conversation_data_url) or die "Couldn't get $conversation_data_url";
			my $conversation_data = from_json $conversation_data_content;
			$conversation_data->{conversation_info}->{id} = $conversation_id;
			
			printt $conversation_id;
			import($domain, $conversation_data);
			
		}
		
	}
	set_last_modified($start_time);
	printt 'Done';
}


sub import {
	my ($domain, $conversation_data) = @_;
	
	my $group = find_or_create_group($domain, $conversation_data->{conversation_info}) or return undef;
	my $request_message = import_message($domain, $conversation_data, $group, 'request', 'a', 'b', 'html');
	my $replay_message = import_message($domain, $conversation_data, $group, 'reply', 'b', 'a', 'plain');
	
}


sub import_message {
	my ($domain, $data, $group, $message_type, $from_side, $to_side, $body_type) = @_;
	print " $message_type";
    my $message_data = $data->{$message_type} or return undef;
    
    my $from = $data->{conversation_info}->{$from_side} or return undef;
    my $to = $data->{conversation_info}->{$to_side} or return undef;
    
	my $message;
    my $error_message;
    # From
    my ($frm_name, $frm_email) = extract_email($from);
    
    # Hash id
    my $message_id = md5_hex($data->{conversation_info}->{id}."$message_type".$message_data->{created});
    print "." and return undef if schema->resultset('Message')->find({source => $source_name, message_id => $message_id});
    
    print "A" if $message_data->{attachments};
    
    try{
		# Create
	    my $response = StoreMail::Message::new_message(							
					direction => 'o',
					message_id => $message_id, 
					domain => $domain,
					source => $source_name,
					group_id => $group->id,
					subject => $group->name,
					date => $message_data->{created},
					body => $message_data->{message}, 
					body_type => $body_type,
					from => email_str($frm_name, domain_email($group->domain)),
					reply_to => email_str($group->name, $group->email),
					to => $to,
					attachments => $message_data->{attachments},
				);
		$message = $response->{message};
		print "+";
    }
    catch {	
    	printt "FAILED TO SEND: " . to_json($data) ." \nERROR:". $_;
    };

    # Message created    
    return $message ? $message->id : undef;
}


sub find_or_create_group {
	my ($domain, $params) = @_;
	
	# Find group by id
    my $group;
    my $new;
    my $error_message; 
    try{
		# Create
		($group, $new) = StoreMail::Group::new_group($domain, $params);
    }
    catch {	
    	$error_message = "FAILED TO CREATE GROUP: " . to_json($params) . "\n ERROR: " . to_dumper($_);
    	printt $error_message;
    };

	printt $error_message and return undef if $error_message;
    printt 'Error. Group not created' and return undef unless $group;

	# Already exists    
	printt "Already exists, but different! \n" and return undef if $new == -1;	
	
	return $group;
	
}


1;
