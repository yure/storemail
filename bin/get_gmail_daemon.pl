#!/usr/bin/env perl
# get_gmail.pl
use Dancer ':script';

use Mail::IMAPClient;
use Dancer::Plugin::DBIC qw(schema resultset rset);
use StoreMail::Email;
use StoreMail::Message;
use MIME::QuotedPrint::Perl;
use MIME::Base64;
use Email::MIME;
use Time::ParseDate;
use DateTime;
use Try::Tiny; 
use Encode qw(decode);
use File::Path qw(make_path remove_tree);
use FindBin;
use Cwd qw/realpath getcwd/;
use Getopt::Long;
use Proc::Daemon;
use Dancer::Plugin::Email;
use File::Spec::Functions;
use Digest::MD5 qw(md5_hex);
sub trim {	my $str = shift; $str =~ s/^\s+|\s+$//g if $str; return $str;}
my ($imap, $initial, $appdir, $logfile, $account_emails);

sub logl { 
	my($txt) = @_;
	open(my $FH, '>>', catfile($appdir, 'logs', $logfile)); 
	$|++; print $FH "\n".$txt;
	close $FH;
} 
sub logt { 
	my($txt) = @_;
	open(my $FH, '>>', catfile($appdir, 'logs', $logfile)); 
	$|++; print $FH "\n".localtime().' | '.$txt;
	close $FH;
}
sub logi { 
	my($txt) = @_;
	open(my $FH, '>>', catfile($appdir, 'logs', $logfile)); 
	$|++; print $FH $txt;
	close $FH;
}

sub fetch_all {	
	my $gmail = config->{gmail};
	$account_emails  = {map {config->{gmail}->{accounts}->{$_}->{username} => 1} keys config->{gmail}->{accounts}};	
	for my $account_name (keys config->{gmail}->{accounts}){
		logl "$account_name:";
		my $account = config->{gmail}->{accounts}->{$account_name};
		$imap = log_in($account);
		unless($imap){
			logt 'Unable to log in';
			next;
		}
		$imap->Peek(1);
		$imap->Uid(1);
			
		$imap->select('INBOX') or logt "Select INBOX error: ", $imap->LastError, "\n";
		my @inbox = $imap->messages;
		logi " In: ";
		process_emails(\@inbox, 'i', $account);

		$imap->select('[Gmail]/Sent Mail') or logt "Select INBOX error: ", $imap->LastError, "\n";;
		my @outbox = $imap->messages;
		logi " Out: ";
		process_emails(\@outbox, 'o', $account);
			
	}
	logt 'Inital import completed' if $initial;

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
	my ($messages, $direction, $account) = @_;
	my @messages_save_queue;
	my $found = 0;
	# Reverse list and keep adding until you find message in db
	for my $mail_id ($initial ? @$messages : reverse @$messages) {
		try {
			no warnings 'exiting';
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
				unless($initial){
					logi '-';
					next if $account_emails->{$message_params->{from}};
					$found++;
					last if $found >= 3;	# If for some reason they get mixed	 	
					next;	
				} else {
					logi '.';
					next;
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
			
			my $plain_body = extract_body($struct, $imap, $mail_id, 'PLAIN') ;
			
			#$raw_body = undef if $raw_body eq '' or $body eq $raw_body;
			
			$message_params->{body} = $html_body || $plain_body;
			# Remove emoticons (utf8 mysql issue)
			$message_params->{body} =~ s/[^[:ascii:]\x{1F600}-\x{1F64F}]+//g;

			$message_params->{domain} = $account->{domain} || config->{domain};			
			$message_params->{body_type} = $html_body ? 'html' : 'plain';
			$message_params->{raw_body} = $raw_html_body if defined $raw_html_body and $raw_html_body ne $html_body;
			$message_params->{plain_body} = $plain_body unless $message_params->{body_type} eq 'plain';
			$message_params->{direction} = $direction;
			$message_params->{source} = $account->{username};
			
			$message_params->{mail_str} = $imap->message_string($mail_id);
			#$message_params->{tags} => '';
	
			if($initial){
				save_message($message_params);
			} 
			else {
				unshift @messages_save_queue, $message_params;
				logi '|';
			}
		}
		catch {
				logt "Fetching email with id $mail_id was not successfull!!! $_ \n";
		}
	}
	# Save queue
		
	for my $message_params (@messages_save_queue){
		try {save_message($message_params)}
		catch {logt "Saving email with id ".$message_params->{message_id}." was not successfull!!! $_";};
	}
}

sub save_message {
	my $message_params = shift;
	
	# New message	
			my $message = StoreMail::Message::new_message(	%$message_params );
			
			if($message){
	
				# Attachments
				my $mail_str = $message_params->{mail_str};
				my $dir = "$appdir/public/attachments/".$message->attachment_id_dir;
				Email::MIME->new($mail_str)->walk_parts(sub {
					my($part) = @_;
			  		return unless defined $part->content_type and $part->content_type =~ /\bname="([^"]+)"/;  # " grr...
			  		system( "mkdir -p $dir" ) unless (-e $dir); 
					my $name = "$dir/$1";
					#logt "$0: writing $name...\n";
					open my $att_fh, ">", $name or warn "$0: open $name: $!";
					close $att_fh or warn "$0: close $name: $!";
				});
				logi '['.$message->id.": ".$message->frm.", ".$message->date.'] ';
				
			}
			
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

#-------- DAEMON STUFF --------
$appdir = config->{appdir};
my $dir = config->{pid_dir} ? catfile(config->{pid_dir}, 'storemail') : "$appdir/run";
system( "mkdir -p $dir" ) unless (-e $dir);
my $pf = catfile($dir, "get_gmail.pid");

my $daemon = Proc::Daemon->new(
	pid_file => $pf,
	work_dir => getcwd()
);
# are you running?  Returns 0 if not.
my $pid = $daemon->Status($pf);
my $daemonize = 1;

GetOptions(
    'daemon!' => \$daemonize,
    "help"    => \&usage,
    "reload"  => \&reload,
    "restart" => \&restart,
    "start"   => \&run,
    "status"  => \&proc_status,
    "stop"    => \&stop,
    "init"    => \&init_import,
    ) or die $!;
exit(0);

sub stop {
        if ($pid) {
	        print "Stopping pid $pid...\n";
	        if ($daemon->Kill_Daemon($pf)) {
		        print "Successfully stopped.\n";
		        logt "Service stopped.";
	        } else {
		        print "Could not find $pid.  Was it running?\n";
	        }
         } else {
                print "Not running, nothing to stop.\n";
         }
}


sub proc_status {
	if ($pid) {
		print "Running with pid $pid.\n";
	} else {
		print "Not running.\n";
	}
}


sub run {
	$logfile = 'get_gmail.log';
	if (!$pid) {
		print "Starting...\n";
		if ($daemonize) {
			# when Init happens, everything under it runs in the child process.
			# this is important when dealing with file handles, due to the fact
			# Proc::Daemon shuts down all open file handles when Init happens.
			# Keep this in mind when laying out your program, particularly if
			# you use filehandles.
			$daemon->Init;
		}

		logt "Service starting...";
		my $sleep = config->{get_gmail_sleep} || 10;
		die "Set some IMAP accounts in config!" unless config->{gmail} and config->{gmail}->{accounts};
		while (1) {
			
			
			try{
	            fetch_all();     
			}
			catch {
				email {
			        from    => 'get.gmail@informa.si',
			        to      => config->{admin_email},
			        subject => 'Get Gmail error',
			        body    => $_,
			    };
			};			
                        # this example writes to a filehandle every 5 seconds.
            logt "Sleeping $sleep seconds.";
			sleep $sleep;
		}
	} else {
		print "Already Running with pid $pid\n";
	}
}


sub init_import {
		print "Starting initial import...\n";
		$logfile = 'get_gmail_init.log';
		logt "Service starting...";
			
		$initial = 1; #$args{'-i'};
		logt "Starting initial import!" if $initial;
			
		die "Set some IMAP accounts in config!" unless config->{gmail} and config->{gmail}->{accounts};
		
        fetch_all();     
}


sub usage
{
    my ($opt_name, $opt_value) = @_;
    print "your usage text goes here...\n";
    exit(0);
}


sub reload
{
    my ($opt_name, $opt_value) = @_;
    print "reload process not implemented.\n";
}


sub restart
{
    my ($opt_name, $opt_value) = @_;
    &stop;
    &run;
}
