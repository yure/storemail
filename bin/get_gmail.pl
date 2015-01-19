use Dancer ':script';

use Mail::IMAPClient;
use Dancer::Plugin::DBIC qw(schema resultset rset);
use Servicator::Email;
use Servicator::Message;
use MIME::QuotedPrint::Perl;
use MIME::Base64;
use Email::MIME;
use Time::ParseDate;
use DateTime;
use Encode qw(decode);
use File::Path qw(make_path remove_tree);
use FindBin;
use Cwd qw/realpath/;
my $appdir = realpath( "$FindBin::Bin/..");

my %args = @ARGV;

my $sleep = $args{'--sleep'} || 5;

my $server   = $args{'-s'} 		|| $args{'--server'} 	|| config->{catch_all}->{host};
my $user     = $args{'-u'} 		|| $args{'--user'} 		|| config->{catch_all}->{username};
my $password = $args{'-p'} 		|| $args{'--password'} 	|| config->{catch_all}->{password};
my $ssl      = $args{'--ssl'} 							|| config->{catch_all}->{ssl};
my $port     = $args{'--port'} 							|| config->{catch_all}->{port};
my $direction= $args{'-d'} 		|| $args{'--direction'} || 'i';

my @accounts = (
	{
		user => $user,
		password => $password, 
	}
);

print "Use with args: 
-s --server 
-u --user
-p --password
--ssl
--port
--sleep
-d --direction (default i = incoming) [i, o]

Service started with
$server, $user, ******, SSL: $ssl, $port

";
# Do not read emails
my $domain;

my $imap = Mail::IMAPClient->new(
	Server   => $server,
	User     => $user,
	Password => $password,
	Ssl      => $ssl,
	Port     => $port,
);
$imap->Peek(1);
$imap->Uid(1);

my @folders = $imap->folders or die "Could not list folders: $@\n";

while(1){
	
	for my $account (@accounts){
		$imap->select('[Gmail]/All Mail') or die "Select INBOX error: ", $imap->LastError, "\n";;
		$imap->select('INBOX') or die "Select INBOX error: ", $imap->LastError, "\n";
		my @unread = $imap->unseen or warn "Could not find unseen msgs: $@\n";
		my @primerjam = $imap->search('FLAGGED "primerjam"') or warn "search failed: $@\n";
		my @primerjam2 = $imap->search('FLAGS', "primerjam") or warn "search failed: $@\n";
		my @primerjam3 = $imap->search('FLAGS primerjam') or warn "search failed: $@\n";
		my @primerjam4 = $imap->search('primerjam') or warn "search failed: $@\n";
		my @primerjam41 = $imap->search('neki') or warn "search failed: $@\n";
		my @primerjam5 = $imap->search('PRIMERJAM') or warn "search failed: $@\n";
		my @primerjam6 = $imap->search('\\primerjam') or warn "search failed: $@\n";
		my @primerjam7 = $imap->search('\\PRIMERJAM') or warn "search failed: $@\n";
		
		my $last_email = schema->resultset('GmailFetch')->search({username => $account->{user}}, {order_by => 'id DESC'})->first;
		my @since = $imap->since(time - 60 * 60 * 24) or warn "No recent msgs: $@\n";
		if ($last_email){
			my @since = $imap->since($last_email->mail_epoch) or warn "No recent msgs: $@\n";
			next unless @since;
		}
		
		$imap->select('INBOX') or die "Select INBOX error: ", $imap->LastError, "\n";
		my @inbox = $imap->messages;
		my @inbox_sorted = $imap->sort('Date', 'UTF-8', 'ALL');
		process_emails(\@inbox, 'i');

		$imap->select('[Gmail]/Sent Mail') or die "Select INBOX error: ", $imap->LastError, "\n";;
		my @outbox = $imap->messages;
		process_emails(\@outbox, 'o');
		
	}

	sleep($sleep);
}


sub process_emails {
	my ($messages, $direction) = @_;
	for my $mail_id (@$messages) {
		my $msg_uid = $imap->message_uid($mail_id);
		my $headers = $imap->parse_headers( $mail_id, "Date", "Subject", "To", "From" );
		my $all = $imap->parse_headers( $mail_id, "ALL");
		my $message_id = $all->{'Message-ID'};
		
		# Reverse list and keep adding until you find message in db
		
		#$imap->set_flag('informa', $mail_id);
		#$imap->set_flag('primerjam', $mail_id);
		#$imap->set_flag('PRIMERJAM', $mail_id);
		#$imap->set_flag('\\primerjam', $mail_id);
		#$imap->set_flag('\\Primerjam', $mail_id);
		$imap->set_flag('krneki', $mail_id);
		my @flags = $imap->flags($mail_id) or die "Could not flags: $@\n";
		$imap->set_flag('neki', $mail_id);
		my @flags2 = $imap->flags($mail_id) or die "Could not flags: $@\n";
		
		# Message body
		my $struct = $imap->get_bodystructure($mail_id);
			# Simple mail
		my $body = extract($struct, $imap, $mail_id);
			# Multipart mail
		unless($body){
			foreach my $dumpme ($struct->bodystructure()) {
				next unless $dumpme->bodytype() eq "TEXT";
				$body="";
				$body=extract($dumpme,$imap,$mail_id );
			}
		}
		$body = decode("UTF-8",decode_qp($body));

		# From
		my $from = $headers->{From}[0];

		# To
		my (@to_email) = split ',', $headers->{To}[0];

		# Subject
		my $subject = decode("UTF-8", $headers->{Subject}[0]);

		# Datetime
		my $epoch = parsedate($headers->{Date}[0]);
		my $datetime = DateTime->from_epoch( epoch => $epoch );

		# Recieved
		my (undef, $received) = split '; ', $headers->{Received}[0];
		my $received_epoch = parsedate($received);		

		# New message	
		my $message = Servicator::Message::new_message(				
			from => $from,
			to   => \@to_email,
			body         => $body,
			subject => $subject,
			direction => $direction,
			date => $datetime->ymd." ".$datetime->hms,
		);
		
		if($message){
			# Save gmail fetch
		    my $gmail_fetch = schema->resultset('GmailFetch')->create({
		    	id => $message_id,
		    	username => $user,
		    	epoch => $epoch,
		    });		

			# Attachments
			my $mail_str = $imap->message_string($mail_id);
			my $dir = "$appdir/public/attachments/".$message->id;
			Email::MIME->new($mail_str)->walk_parts(sub {
				my($part) = @_;
		  		return unless $part->content_type =~ /\bname="([^"]+)"/;  # " grr...
		  		system( "mkdir -p $dir" ) unless (-e $dir); 
				my $name = "$dir/$1";
				print "$0: writing $name...\n";
				open my $fh, ">", $name or die "$0: open $name: $!";
				print $fh $part->content_type =~ m!^text/! ? $part->body_str : $part->body or die "$0: print $name: $!";
				close $fh or warn "$0: close $name: $!";
			});
			print "Email fetched: $subject from $from\n";
		}
	}
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
	#my $from = '';
	#my $to = substr(Servicator::Email::email_break_text, 0, -1); # Decoding can loose last char...
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


sub trim {
	my $str = shift;
	$str =~ s/^\s+|\s+$//g;
	return $str;
}

sub extract  {
	my ($process, $imap, $msg) = @_;
	if ($process->bodytype eq "TEXT") {
	   if ($process->bodyenc eq "base64") {
	        return decode_base64($imap->bodypart_string($msg,$process->id));
	        }
	   elsif (index(" -7bit- -8bit- -quoted-printable- ",lc($process->bodyenc)) !=-1  ) {
	        return $imap->bodypart_string($msg,$process->id);
	        }
	print "\n==========Insert new decoder here============";
	print "\n".$imap->bodypart_string($msg,$process->id);
	print "\n=================================================";
	
	}
	
	return "";
}