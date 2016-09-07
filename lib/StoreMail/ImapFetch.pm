package StoreMail::ImapFetch;
use Dancer ':syntax';

use Mail::IMAPClient;
use Dancer::Plugin::DBIC qw(schema resultset rset);
use StoreMail::Email;
use StoreMail::Message;
use StoreMail::Helper;
use StoreMail::SMS;
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
	for my $account_name (sort keys config->{gmail}->{accounts}){
		
		
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
		print ' Unable to log in';
		return undef;
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
	my $found_count = 0;

	# Reverse list and keep adding until you find message in db
	for my $mail_id ($args->{initial} ? @$messages : reverse @$messages) {
		try {
			my ($message, $found) = process_email($mail_id, $direction, $account, $args);
			unshift @messages_save_queue, $message if $message;
			$found_count += $found if $found;
		}
		catch {
			printt "Fetching email with id $mail_id was not successfull!!! $_ \n";
		};
		last if $found_count > 3;
	}

	# Save queue
	for my $message_params (@messages_save_queue){
		try {save_message($account, $message_params) or print 'x'}
		catch {printt "Saving email with id ".$message_params->{message_id}." was not successfull!!! $_";};
	}
}

sub process_email {
	my ($mail_id, $direction, $account, $args) = @_;
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
			return (undef, 1) if $account_emails->{$message_params->{from}};
			return undef, 1;	
		} else {
			print '.';
			return undef;
		}
	}
	my $mime = Email::MIME->new($imap->message_string($mail_id));


	# To
	$message_params->{to} = [map {clean_parenthesis($_)} split ',', $headers->{To}[0]] if defined $headers->{To}[0];
	$message_params->{cc} = [map {clean_parenthesis($_)} split ',', $headers->{Cc}[0]] if defined $headers->{Cc}[0];
	$message_params->{bcc} = [map {clean_parenthesis($_)} split ',', $headers->{Bcc}[0]] if defined $headers->{Bcc}[0];

	# Subject
	$message_params->{subject} = decode("UTF-8", $headers->{Subject}[0]);
	$message_params->{subject} = $imap->subject($mail_id);

	# Datetime
	my $epoch = parsedate($headers->{Date}[0]);
	my $datetime = DateTime->from_epoch( epoch => $epoch ) if $epoch;
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
		save_message($account, $message_params);
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
	$str = decode("MIME-Header", $str);
	$str = encode('UTF-8', $str);
	$str =~ s/([\xF0-\xF7]...)|([\xE0-\xEF]..)/_/g;
	$str = decode('UTF-8', $str);
	$str =~ s/[^[:ascii:]]//g;
	return $str;
}

sub save_message {
	my ($account, $message_params, $retry) = @_;
		
	# Incoming sms
	if($account->{sms_gateway}){
		# IN SMS | +38641235094 | gsm-2.4(38631463715) | 2016/06/09 12:15:13
		my ($type, $from, $port_number, $datetime) = split ' \| ', $message_params->{subject};
		my $listener_gateway_settings = config->{gateways}->{$account->{sms_gateway}};
		
		if($type and $from and $port_number and $datetime){
			my ($port, undef) = split '\(', $port_number;	
			
			# Temporaray init port name fix
			my $old_port_name = {
				'1' 			=> 'gsm-1.1',
				'2' 			=> 'gsm-1.2',
				'3' 			=> 'gsm-1.3',
				'4' 			=> 'gsm-1.4',
		      	'Board-2-gsm-1' => 'gsm-2.1', 
		      	'Board-2-gsm-2' => 'gsm-2.2', 
		      	'Board-2-gsm-3' => 'gsm-2.3', 
		      	'Board-2-gsm-4' => 'gsm-2.4', 
			};
		   	$port = $old_port_name->{$port} if $old_port_name->{$port}; 
			
			$datetime =~ s/\//-/g;
			$from =~ s/\+/00/g;
			unless( $from){
				1;
			}
			
			# Recieve timezone fix
			my $timezone = $listener_gateway_settings->{timezone} || config->{timezone};
			my $format = new DateTime::Format::Strptime(pattern => "%Y-%m-%d %H:%M:%S", time_zone => $listener_gateway_settings->{timezone});
			my $time = $format->parse_datetime($datetime);
			$time->set_time_zone("UTC");
			my $new_date = $time->ymd() . ' ' .$time->hms();
			
			my $body = trim $message_params->{body};
			my $error;
			try{
				StoreMail::SMS::save_sms( $account->{sms_gateway}, $port, $from, $body, $new_date );
			} catch {
				$error = $_;
			};
			return if $error;
		}
	}
	
		
	# New message	
	try{
		#print "\n".$message_params->{subject}."\n";
		my $response = StoreMail::Message::new_message(	%$message_params );
		my $message = $response->{message};
		
		if($message){
			print '['.$message->id.": ".$message->frm.", ".$message->date.'] ';
			return 1;
		}
		else {
			print "X";
		}
		return undef;
	} catch {
		#print $_;
		for my $key (keys %$message_params){
			$message_params->{$key} = remove_utf8_4b $message_params->{$key} if $message_params->{$key}; 
		}
		# Try again with cleaned body
		return save_message($account, $message_params, 1) unless $retry;
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
