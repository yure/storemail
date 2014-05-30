use Dancer ':script';

use Mail::IMAPClient;
use Dancer::Plugin::DBIC qw(schema resultset rset);
use Servicator::Email;
use Servicator::Message;
use MIME::QuotedPrint::Perl;
use Encode qw(decode);

my %args = @ARGV;

while(1){
	
	my $domain; # = $args{'-d'};

	my $imap = Mail::IMAPClient->new(
		Server   => config->{catch_all}->{host},
		User     => config->{catch_all}->{username},
		Password => config->{catch_all}->{password},
		Ssl      => config->{catch_all}->{ssl},
		Port     => config->{catch_all}->{post},
	);
	$imap->select('INBOX') or die "Select INBOX error: ", $imap->LastError, "\n";
	my @unread = $imap->unseen;

	if (@unread) {

		debug "New email found. Processing...";
	
		#splice @unread, 5;
		for my $mail_id (@unread) {
			my $hashref = $imap->parse_headers( $mail_id, "Date", "Subject", "To", "From" );
	
			# TODO: weed out random mail
	
			# Conversation ID
			my $emails = $hashref->{To}[0];
			my ($email) = split ',', $emails;
			my ($conv_id, $domain) = $email =~ /<(.*?)@(.*?)>/s;
			($conv_id, $domain) = $email =~ /(.*?)@(.*?)$/s unless $conv_id;
			$conv_id =~ s/\@$domain//g;
	
			my $conversation = schema->resultset('Conversation')->find( $conv_id ."@". $domain );
			unless ($conversation){
				debug "Invalid mail or conversation";
				$imap->see($mail_id) or warn "Could not see: $@\n";
				next;
			}
			
			# Message body
			my $body = extract_body( $imap->body_string($mail_id) );
	
			my $b_struc = $imap->get_bodystructure($mail_id);
	
			# Sender
			my $sender_email = $hashref->{From}[0];
			($sender_email) = $sender_email =~ /<(.*?)>/s;
	
			# Check sender
			my $user_sender = $conversation->search_related( 'users', { email => $sender_email } )->first;
			debug { error => 'Sender not found' } unless $user_sender;
	
			#$imap->subject($mail_id)
	
			Servicator::Message::new_message(
				id           => $conv_id,
				domain       => $domain,
				sender_email => $user_sender->email,
				recipients   => $conversation->recipients($user_sender),
				body         => $body
			);
		}
	}
	else{
		warn "No new emails\n";
	}

	sleep(5);
}


sub extract_body {
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
	my $from = '';
	my $to = substr(Servicator::Email::email_break_text, 0, -1); # Decoding can loose last char...
	($wanted) = $body =~ /$from(.*?)$to/s;
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


sub trim {
	my $str = shift;
	$str =~ s/^\s+|\s+$//g;
	return $str;
}