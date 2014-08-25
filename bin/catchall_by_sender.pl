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
my $port     = $args{'--port'} 							|| config->{catch_all}->{post};
my $direction= $args{'-d'} 		|| $args{'--direction'} || 'i';

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

while(1){
	
	my $domain;

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
			my $headers = $imap->parse_headers( $mail_id, "Date", "Subject", "To", "From" );
			my $all = $imap->parse_headers( $mail_id, "ALL");
			
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

			# New message	
			my $message = Servicator::Message::new_message(				
				from => $from,
				to   => \@to_email,
				body         => $body,
				subject => $subject,
				direction => $direction,
				date => $datetime->ymd." ".$datetime->hms,
			);

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
	else{
		warn "No new emails\n";
	}

	sleep($sleep);
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