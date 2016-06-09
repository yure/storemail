package StoreMail::ImapFetch;
use Dancer ':syntax';

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
use Encode qw(decode encode);
use Dancer::Plugin::Email;
use Digest::MD5 qw(md5_hex);
my ($imap, $initial, $logfile, $account_emails);
my $appdir = config->{appdir};


sub fetch_all {
	my $args = {@_};		
	my $gmail = config->{gmail};
	$account_emails  = {map {config->{gmail}->{accounts}->{$_}->{username} => 1} keys config->{gmail}->{accounts}};	
	for my $account_name (keys config->{gmail}->{accounts}){
		
		
		print "\n$account_name:";
		my $account = config->{gmail}->{accounts}->{$account_name};

		fetch_account($args, $account);
			
	}
	printt 'Inital import completed' if $args->{initial};
}


sub fetch_account {
	my ($args, $account) = @_;
	$imap = log_in($account);
	unless($imap){
		printt 'Unable to log in';
		next;
	}
	$imap->Peek(1);
	$imap->Uid(1);
		
	fetch_inbox($args, $imap, $account, 'INBOX', 'i');
	fetch_inbox($args, $imap, $account, '[Gmail]/Sent Mail', 'o');
}


sub fetch_inbox {
	my ($args, $imap, $account, $inbox, $direction) = @_;
	
	$imap->select($inbox) or printt "Select $inbox error: ", $imap->LastError, "\n";
	my @inbox = $imap->messages;
	print " $inbox: ";
	process_emails(\@inbox, $direction, $account, $args);
}


sub log_in {
	my $account = shift;
	return Mail::IMAPClient->new(
			Server   => $account->{host},
			User     => $account->{username},
			Password => $account->{password},
			Ssl      => $account->{ssl},
			Port     => $account->{port},
		);
		
}

sub process_emails {
	my ($messages, $direction, $account, $args) = @_;
	my @messages_save_queue;
	my $found = 0;

	# Reverse list and keep adding until you find message in db
	for my $mail_id ($args->{initial} ? @$messages : reverse @$messages) {
		try {
			my $message = process_email($mail_id, $direction, $account, $found, $args);
			unshift @messages_save_queue, $message if $message;
		}
		catch {
			printt "Fetching email with id $mail_id was not successfull!!! $_ \n";
		};
	}

	# Save queue
	for my $message_params (@messages_save_queue){
		try {save_message($message_params)}
		catch {printt "Saving email with id ".$message_params->{message_id}." was not successfull!!! $_";};
	}
}

sub process_email {
	my ($mail_id, $direction, $account, $found, $args) = @_;
	my $headers = $imap->parse_headers( $mail_id, "Date", "Subject", "To", "From" );
	my $all = $imap->parse_headers( $mail_id, "ALL");
	my $message_params = {};
	
	
	# ID
	my $message_id;
	$message_id = trim $all->{'Message-ID'}[0] if $all->{'Message-ID'};
	$message_id = trim $all->{'Message-Id'}[0] if $all->{'Message-Id'};
	$message_id = to_dumper $all unless $message_id;
	$message_id = md5_hex $message_id;
	$message_params->{message_id} = $message_id;
	# From
	$message_params->{from} = clean_parenthesis($headers->{From}[0]);

	# End if already exists
	my $existing = schema->resultset('Message')->find({source => $account->{username}, message_id => $message_id});
	if($existing){				
		unless($args->{initial}){
			print '-';
			return undef if $account_emails->{$message_params->{from}};
			$found++;
			last if $found >= 3;	# If for some reason they get mixed	 	
			return undef;	
		} else {
			print '.';
			return undef;
		}
	}
	$found = 0;
	my $mime = Email::MIME->new($imap->message_string($mail_id));


	# To
	$message_params->{to} = [map {clean_parenthesis($_)} split ',', $headers->{To}[0]] if defined $headers->{To}[0];
	$message_params->{cc} = [map {clean_parenthesis($_)} split ',', $headers->{Cc}[0]] if defined $headers->{Cc}[0];
	$message_params->{bcc} = [map {clean_parenthesis($_)} split ',', $headers->{Bcc}[0]] if defined $headers->{Bcc}[0];

	# Subject
	$message_params->{subject} = decode("UTF-8", $headers->{Subject}[0]);

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
		$imap = log_in($account);
		$struct = $imap->get_bodystructure($mail_id);				
	};
	
	# Body
	my $raw_html_body = extract_body($struct, $imap, $mail_id, 'HTML', $mime);
	my $html_body = clean_html($raw_html_body);			
	
	my $plain_body = extract_body($struct, $imap, $mail_id, 'PLAIN');
	
	#$raw_body = undef if $raw_body eq '' or $body eq $raw_body;
	
	$message_params->{body} = $html_body || $plain_body;
	# Remove emoticons (utf8 mysql issue)
	

	$message_params->{domain} = $account->{domain} || config->{domain};			
	$message_params->{body_type} = $html_body ? 'html' : 'plain';
	$message_params->{raw_body} = $raw_html_body if defined $raw_html_body and $raw_html_body ne $html_body;
	$message_params->{plain_body} = $plain_body unless $message_params->{body_type} eq 'plain';
	$message_params->{direction} = $direction;
	$message_params->{source} = $account->{username};
	
	$message_params->{mail_str} = $imap->message_string($mail_id);
	#$message_params->{tags} => '';

	if($args->{initial}){
		save_message($message_params);
		return undef;
	} 
	else {
		# unshift @messages_save_queue, $message_params;
		print '|' and return $message_params;
	}
}

sub remove_utf8_4b {
	my $str = shift;
	return $str unless defined $str;
	$str = encode('UTF-8', $str);
	$str =~ s/([\xF0-\xF7]...)|([\xE0-\xEF]..)/_/g;
	$str = decode('UTF-8', $str);
	return $str;
}

sub save_message {
	my ($message_params, $retry) = @_;
	
	# New message	
	try{
		my $response = StoreMail::Message::new_message(	%$message_params );
		my $message = $response->{message};
		
		if($message){
			print '['.$message->id.": ".$message->frm.", ".$message->date.'] ';
			return 1;
		}
		return undef;
	} catch {
		for my $key (keys %$message_params){
			$message_params->{$key} = remove_utf8_4b $message_params->{$key} if $message_params->{$key}; 
		}
		# Try again with cleaned body
		save_message($message_params, 1) unless $retry;
		return undef;
	};
	
			
}

sub clean_html {
	my $body = shift;
	return undef unless $body;
	$body =~ s/<style(.+?)<\/style>//smg; # Remove style tag
	return $body;	
}

sub clean_parenthesis {
	my $str = shift;
	return undef unless defined $str;
	$str = ''.$str;
	$str =~ s/"//g; # Remove style tag
	$str =~ s/'//g;
	return $str;	
}

sub clean_body {
	my $body = shift;
	
#	return $body; #Untill we cover all cases, do noting
	
	my ($clean_body, $wanted, $mailId);
	$body = decode("UTF-8",decode_qp($body));
	
	
	#my $from = "";
	#my $to = "\r\n";
	#($mailId) = $body =~ /$from(.*?)$to/s;

	#$from = "\r\n\r\n";
	#$to = $mailId;
	
	# Remove all from breake text on 
	#my $from = '';
	#my $to = substr(StoreMail::Email::email_break_text, 0, -1); # Decoding can loose last char...
	#($wanted) = $body =~ /$from(.*?)$to/s;
	
	
	
	$wanted = $body;
	if($wanted){
		$wanted = remove_gmail_code($wanted);
		$wanted = remove_outlook_code($wanted);
		$wanted = trim($wanted);
		$clean_body = $wanted if $wanted;
	}
	
	
	
	# If no text, try bottom post
	unless($clean_body){
		
	}
	
	# Remove 
	
	return $clean_body;
}


sub remove_gmail_code {
	my $body = shift;
	my $clean_body;
	my $gmail_id;
	
	# Check if gmail format
	my $first_row;
	($first_row) = $body =~ /(--.{28}?)\n/s;
	return $body unless $first_row;
	
	# Remove On Thu, May 29, 2014 at 9:01 AM, John <name@email.com> wrote:
	# Remove --001a1134d7c0f749fe04fa848617 Content-Type: text/plain; charset=UTF-8
	
	#my $from = "--(.+?)\nContent-Type: (.+?); charset=(.+?)\n";
	my $from = "\n\n";
	my $to = "\nOn(.+?)at(.+?),(.+?)<(.+?)@(.+?)> wrote:";
	($clean_body)= $body =~ /$from(.*?)$to/s;	
	
	return $clean_body ? $clean_body : $body;
}


sub remove_outlook_code {
	my $body = shift;
	my $clean_body;
	my $gmail_id;
	# Remove On Thu, May 29, 2014 at 9:01 AM, John <name@email.com> wrote:
	# Remove --001a1134d7c0f749fe04fa848617 Content-Type: text/plain; charset=UTF-8
	
	my $from = "";
	my $to = "\nOn(.+?),(.+?) wrote:";
	($clean_body)= $body =~ /$from(.*?)$to/s;	
	
	return $clean_body ? $clean_body : $body;
}


sub extract_body  {
	my ($struct, $imap, $msg, $subtype, $mime) = @_;
	if ($struct->bodytype eq "MULTIPART") {
		my $i = 0;
		for my $part ($struct->bodystructure()) {
			my $body = extract_body($part, $imap, $msg, $subtype, $mime->{parts} ? $mime->{parts}->[$i] : undef);
			$i++;
			return $body if $body;
		}
	}
	if (lc $struct->bodytype eq lc "TEXT" and lc $struct->bodysubtype eq lc $subtype) {
		my $text = $imap->bodypart_string($msg,$struct->id);
		
		# Skip attachments
		my $params = $mime->{header}->{headers};
		for my $param (@$params){
			if (index($param, 'attachment;') != -1){
				return undef;
			}
		}
		
	    $text = decode_qp($text) if (lc $struct->bodyenc eq lc "QUOTED-PRINTABLE" );
	    $text = decode_base64($text) if (lc $struct->bodyenc eq lc "base64" );
		my $encoding = $struct->bodyparms->{CHARSET} if $struct->bodyparms and ref $struct->bodyparms eq 'HASH';
	    my @bad_encodings = qw/ansi_x3.110-1983/;
		if($encoding){
			return decode($encoding, $text);
		}
	}
	
	return undef;
}

1;