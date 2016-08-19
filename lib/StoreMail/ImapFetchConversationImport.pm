package StoreMail::ImapFetchConversationImport;
use Dancer ':syntax';

# Importing old conversations from CRM system. Only for transitional period.

use Mail::IMAPClient;
use Dancer::Plugin::DBIC qw(schema resultset rset);
use StoreMail::Email;
use StoreMail::Message;
use StoreMail::Helper;
use MIME::QuotedPrint::Perl;
use MIME::Base64;
use Email::MIME;
use Time::ParseDate;
use DateTime;
use Try::Tiny; 
use Encode qw(decode);
use Dancer::Plugin::Email;
use Digest::MD5 qw(md5_hex);
my $appdir = config->{appdir};
my $imap;
my $account_emails;
use StoreMail::ImapFetch;

sub fetch_all {
	my $args = {@_};		
	my $gmail = config->{gmail};
	$account_emails  = {map {config->{gmail}->{conversation_accounts}->{$_}->{username} => 1} keys config->{gmail}->{conversation_accounts}};	
	for my $account_name ('start','response'){ #'start',  
		print "\n$account_name:";
		my $account = config->{gmail}->{conversation_accounts}->{$account_name};
		$imap = StoreMail::ImapFetch::log_in($account);
		unless($imap){
			printt 'Unable to log in';
			next;
		}
		$imap->Peek(1);
		$imap->Uid(1);
		$imap->select('Conversation') or printt "Select folder error: ", $imap->LastError, "\n";		
		my @inbox = $imap->messages;		
		process_emails(\@inbox, 'i', $account, initial => $args->{initial});
			
	}
	printt 'Inital import completed' if $args->{initial};
}


sub process_emails {
	my ($messages, $direction, $account, %args) = @_;
	my @messages_save_queue;
	my $found = 0;	
	# Reverse list and keep adding until you find message in db
	for my $mail_id ($args{initial} ? @$messages : reverse @$messages) {
		try {
			print ':';
			no warnings 'exiting';
			my $headers = $imap->parse_headers( $mail_id, "Date", "Subject", "To", "From" );
			my $all = $imap->parse_headers( $mail_id, "ALL");
			my $message_params = {};
			
			# Subject
			my $subject = decode("MIME-Header", $headers->{Subject}[0]);

			# Only conversations
			my ($group_id) = $subject =~ /\[\[([0-9a-z\-]+)\]\]/;
			next if !$group_id or (length $group_id < 13 or length $group_id > 17);
			
			$message_params->{group} = {};
			$message_params->{group}->{id} = $group_id;
			$message_params->{group}->{name} = $subject;
			$message_params->{subject} = $subject;
			
			# ID
			my $message_id;
			$message_id = trim $all->{'Message-ID'}[0] if $all->{'Message-ID'};
			$message_id = trim $all->{'Message-Id'}[0] if $all->{'Message-Id'};
			$message_id = to_dumper $all unless $message_id;
			$message_id = md5_hex $message_id;
			$message_params->{message_id} = $message_id;

			# From
			$message_params->{from} = StoreMail::ImapFetch::clean_parenthesis($headers->{From}[0]);

			# End if already exists
			my $existing = schema->resultset('Message')->find({source => $account->{username}, message_id => $message_id});
			if($existing){				
				unless($args{initial}){
					print '-';
					next if $account_emails->{$message_params->{from}};
					$found++;
					last if $found >= 3;	# If for some reason they get mixed	 	
					next;	
				} else {
					print '.';
					next;
				}
			}
			$found = 0;
			my $mime = Email::MIME->new($imap->message_string($mail_id));
	
	
			# To
			$message_params->{to} = [map {StoreMail::ImapFetch::clean_parenthesis($_)} split ',', $headers->{To}[0]] if defined $headers->{To}[0];
			$message_params->{cc} = [map {StoreMail::ImapFetch::clean_parenthesis($_)} split ',', $headers->{Cc}[0]] if defined $headers->{Cc}[0];
			$message_params->{bcc} = [map {StoreMail::ImapFetch::clean_parenthesis($_)} split ',', $headers->{Bcc}[0]] if defined $headers->{Bcc}[0];
	
	
			# Datetime
			my $epoch = parsedate($headers->{Date}[0]);
			my $datetime = DateTime->from_epoch( epoch => $epoch )->set_time_zone( config->{timezone} ) if $epoch;
			$message_params->{date} = $datetime ? $datetime->ymd." ".$datetime->hms : undef;
	
			# Message body
			my $struct;
			try{
				$struct = $imap->get_bodystructure($mail_id);				
			}
			catch {
				$imap = StoreMail::ImapFetch::log_in($account);
				$struct = $imap->get_bodystructure($mail_id);				
			};
			
			# Body
			my $raw_html_body = StoreMail::ImapFetch::extract_body($struct, $imap, $mail_id, 'HTML', $mime);
			$raw_html_body =~ s/--------\/\/--------.*--------\\\\--------//smg if $raw_html_body;
			my $html_body = StoreMail::ImapFetch::clean_html($raw_html_body);			
			
			my $plain_body = StoreMail::ImapFetch::extract_body($struct, $imap, $mail_id, 'PLAIN');
			$plain_body =~ s/--------\/\/--------.*--------\\\\--------//smg if $plain_body;
			
			$message_params->{body} = $html_body || $plain_body;
			$message_params->{domain} = $account->{domain} || config->{domain};			
			$message_params->{body_type} = $html_body ? 'html' : 'plain';
			$message_params->{raw_body} = $raw_html_body if defined $raw_html_body and $raw_html_body ne $html_body;
			$message_params->{plain_body} = $plain_body unless $message_params->{body_type} eq 'plain';
			$message_params->{direction} = $direction;
			$message_params->{source} = $account->{username};
			
			$message_params->{mail_str} = $imap->message_string($mail_id);
	
			if($args{initial}){
				save_message($message_params, $account);
			} 
			else {
				unshift @messages_save_queue, $message_params;
				print '|';
			}
		}
		catch {
				printt "Fetching email with id $mail_id was not successfull!!! $_ \n";
		}
	}
		
	# Save queue
	for my $message_params (@messages_save_queue){
		try {save_message($message_params, $account)}
		catch {printt "Saving email with id ".$message_params->{message_id}." was not successfull!!! $_";};
	}
}


sub save_message {
	my ($message_params, $account) = @_;
	
	# Process group logic
	$message_params = StoreMail::Group::new_group_from_message($message_params->{domain}, $message_params) if $account->{type} eq 'start';
	$message_params = StoreMail::Group::group_reply_from_message($message_params->{domain}, $message_params) if $account->{type} eq 'reply';
	
	# New message	
	my $response = StoreMail::Message::new_message(
		group_mail_import => 1,	
		%$message_params,
	);
	
	my $message = $response->{message};
	if($message){
		print '['.$message->id.": ".$message->frm.", ".$message->date.'] ';
	}
			
}


1;